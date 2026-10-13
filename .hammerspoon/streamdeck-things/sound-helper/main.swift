import AppKit
import AVFoundation
import CoreAudio
import Foundation

let logPath = NSString(string: "~/.hammerspoon/SoundHelper.log").expandingTildeInPath
let previousLogPath = logPath + ".1"
// Rotate instead of truncate on every launch - otherwise a restart (own
// crash, or the health-check's auto-relaunch after either) silently
// destroys the only record of whatever just went wrong, right when it's
// most needed. Keeps exactly one previous run's log around.
try? FileManager.default.removeItem(atPath: previousLogPath)
try? FileManager.default.moveItem(atPath: logPath, toPath: previousLogPath)
FileManager.default.createFile(atPath: logPath, contents: nil)
let logHandle = FileHandle(forWritingAtPath: logPath)
func writeLogLine(_ line: String) {
    let stamped = line + "\n"
    Swift.print(stamped, terminator: "")
    logHandle?.write(stamped.data(using: .utf8)!)
}

// MARK: - Log levels
//
// Added after a live debugging session where an unconditional per-second
// diagnostic line (IOProc callback count, added to chase a real bug) kept
// firing throughout ordinary playback, not just while something was
// actually wrong - filling the log (and pushing older, more useful
// history out through the single-previous-run rotation above) far faster
// than the sparser lifecycle-event logging that existed before it. error/
// warn always show; info is the reasonable default (lifecycle events:
// taps, mixer rebuilds, engine restarts); debug is for exactly the class
// of high-volume/every-callback/every-gain-tweak diagnostic that caused
// this - opt in only when actively chasing something, the same way the
// callback counter was opted into ad hoc before this existed.
enum LogLevel: Int, Comparable {
    case error = 0
    case warn = 1
    case info = 2
    case debug = 3

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    init(name: String) {
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "error": self = .error
        case "warn", "warning": self = .warn
        case "debug": self = .debug
        default: self = .info
        }
    }
}
// Read once at startup, same pattern as streamdeck-media.lua's
// soundhelper-paused.flag: a plain file rather than an env var, since
// Hammerspoon launches this via `open -g` which has no easy way to pass
// one through. Bump verbosity with e.g. `echo debug >
// ~/.hammerspoon/soundhelper-loglevel` and relaunch.
let logLevelPath = NSString(string: "~/.hammerspoon/soundhelper-loglevel").expandingTildeInPath
let currentLogLevel: LogLevel = {
    guard let raw = try? String(contentsOfFile: logLevelPath, encoding: .utf8) else { return .info }
    return LogLevel(name: raw)
}()
func log(_ level: LogLevel, _ message: @autoclosure () -> String) {
    guard level <= currentLogLevel else { return }
    writeLogLine(message())
}
func logError(_ message: @autoclosure () -> String) { log(.error, message()) }
func logWarn(_ message: @autoclosure () -> String) { log(.warn, message()) }
func logInfo(_ message: @autoclosure () -> String) { log(.info, message()) }
func logDebug(_ message: @autoclosure () -> String) { log(.debug, message()) }

// MARK: - kTCCServiceAudioCapture (private TCC.framework SPI - see
// insidegui/AudioCap's AudioRecordingPermission.swift for the reference).

private typealias PreflightFuncType = @convention(c) (CFString, CFDictionary?) -> Int
private typealias RequestFuncType = @convention(c) (CFString, CFDictionary?, @escaping (Bool) -> Void) -> Void
private let tccHandle: UnsafeMutableRawPointer? = dlopen(
    "/System/Library/PrivateFrameworks/TCC.framework/Versions/A/TCC", RTLD_NOW)
private func tccPreflight() -> Int? {
    guard let tccHandle, let sym = dlsym(tccHandle, "TCCAccessPreflight") else { return nil }
    return unsafeBitCast(sym, to: PreflightFuncType.self)("kTCCServiceAudioCapture" as CFString, nil)
}
private func tccRequest(completion: @escaping (Bool) -> Void) {
    guard let tccHandle, let sym = dlsym(tccHandle, "TCCAccessRequest") else { completion(false); return }
    unsafeBitCast(sym, to: RequestFuncType.self)("kTCCServiceAudioCapture" as CFString, nil, completion)
}
if tccPreflight() != 0 {
    let sem = DispatchSemaphore(value: 0)
    var granted = false
    tccRequest { granted = $0; sem.signal() }
    sem.wait()
    logInfo("TCC granted=\(granted)")
    guard granted else { exit(1) }
}

// MARK: - CoreAudio helpers

func getProcessObjectList() -> [AudioObjectID] {
    var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var dataSize: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
    guard status == noErr else { return [] }
    let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
    var list = [AudioObjectID](repeating: 0, count: count)
    status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &list)
    return status == noErr ? list : []
}
func getPID(_ obj: AudioObjectID) -> pid_t? {
    var address = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyPID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var pid: pid_t = 0
    var size = UInt32(MemoryLayout<pid_t>.size)
    let status = AudioObjectGetPropertyData(obj, &address, 0, nil, &size, &pid)
    return status == noErr ? pid : nil
}
func getIsRunningOutput(_ obj: AudioObjectID) -> Bool {
    var address = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyIsRunningOutput, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    let status = AudioObjectGetPropertyData(obj, &address, 0, nil, &size, &value)
    return status == noErr && value != 0
}
func getBundleID(_ obj: AudioObjectID) -> String? {
    var address = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyBundleID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var bundleID: CFString = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    let status = withUnsafeMutablePointer(to: &bundleID) { ptr -> OSStatus in AudioObjectGetPropertyData(obj, &address, 0, nil, &size, ptr) }
    guard status == noErr else { return nil }
    let str = bundleID as String
    return str.isEmpty ? nil : str
}
func getProcessComm(_ pid: pid_t) -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/ps")
    task.arguments = ["-p", "\(pid)", "-o", "comm="]
    let pipe = Pipe()
    task.standardOutput = pipe
    try? task.run()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let full = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "?"
    return (full as NSString).lastPathComponent
}
// comm is just the executable's own file name, which for some apps (e.g.
// Zoom's "zoom.us") looks nothing like what a person calls the app. Prefer
// the real display name macOS already tracks for GUI apps; comm remains
// the fallback for anything with no NSRunningApplication entry (CLI
// tools, background daemons).
func getProcessDisplayName(_ pid: pid_t, fallback: String) -> String {
    return NSRunningApplication(processIdentifier: pid)?.localizedName ?? fallback
}
func getDefaultOutputDeviceID() -> AudioObjectID? {
    var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var deviceID: AudioObjectID = 0
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
    return status == noErr ? deviceID : nil
}
func getDeviceUID(_ deviceID: AudioObjectID) -> String? {
    var uid: CFString = "" as CFString
    var uidAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var uidSize = UInt32(MemoryLayout<CFString>.size)
    let status = withUnsafeMutablePointer(to: &uid) { ptr -> OSStatus in AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, ptr) }
    return status == noErr ? (uid as String) : nil
}
func getDefaultOutputDeviceUID() -> String? {
    getDefaultOutputDeviceID().flatMap(getDeviceUID)
}
// Diagnostic only.
func getNominalSampleRate(_ deviceID: AudioObjectID) -> Double? {
    var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyNominalSampleRate, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var rate: Double = 0
    var size = UInt32(MemoryLayout<Double>.size)
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &rate)
    return status == noErr ? rate : nil
}

// MARK: - Shared mixer: ONE aggregate device + ONE IOProc for *all*
// currently-tapped processes at once, rebuilt only when membership
// changes. This is the fix for the original bug: one aggregate device
// per tapped process, all naming the same physical speaker as their
// clock master, caused multiple independent renderers to fight over the
// same hardware clock - verified live to produce beat-frequency
// interference (audio pitched down toward inaudible, timescale
// unaffected - the textbook signature of two near-identical signals
// summed slightly out of phase). Verified fix: a single shared aggregate
// with N taps delivers N buffers per callback, in the same order the
// taps were listed when the aggregate was constructed - confirmed live
// with two simultaneous, independently-gained speech sources.
final class GainBox { var value: Float32 = 1.0 }

// MARK: - Playback bridge: hands mixed audio to a standard AVAudioEngine
// player instead of having our aggregate drive the physical output device
// directly. This is the real fix for the Bluetooth call-distortion chain
// investigated above (see the removed pin/restriction/listener code this
// replaced): a reactive "detect the hardware's rate dropped, then
// suspend/rebuild taps" approach only ever shortens the glitch window, it
// can't remove it, and forcing our aggregate's rate to fight a live
// Bluetooth HFP/A2DP negotiation is what got a headset stuck requiring a
// manual reboot. The actual structural problem was that our capture
// aggregate's internal clock/rate was tied directly to the same volatile
// physical hardware. Routing playback through AVAudioEngine instead means
// the *device-adaptive* half of the job - tracking whatever the real
// output is currently doing, resampling into it - is delegated entirely
// to Apple's own mature output path, the same one every untapped app
// already uses successfully. Our side just mixes taps and hands off
// fixed-format buffers; it never touches a real device's properties again.
// Non-interleaved: AVAudioEngine's internal graph connections require it
// (interleaved threw an NSException from -[AVAudioEngine connect:to:format:]
// - confirmed via crash report, EXC_CRASH/SIGABRT inside AUInterfaceBaseV3::
// SetFormat). Tap buffers themselves are interleaved, so the mixing code
// below de-interleaves while summing rather than via a separate pass.
let playbackFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: false)!
let playbackEngine = AVAudioEngine()
let playerNode = AVAudioPlayerNode()
playbackEngine.attach(playerNode)
// Confirmed live: a device-triggered restart (e.g. Bluetooth dropping to
// HFP call mode, which is MONO, not just a lower rate) doesn't get
// reflected in the mainMixerNode->outputNode connection unless we force
// it - the mixer kept declaring a stale 2-channel output against a device
// that had gone 1-channel, and the mismatch produced total silence for
// as long as the call's mic stayed open, with engine.isRunning/isPlaying
// both still reporting true throughout. Disconnecting and reconnecting
// both graph hops on every start forces a fresh format negotiation
// against whatever the device is actually doing right now, instead of
// reusing whatever was true back at the original cold start.
func startPlaybackEngine() {
    playbackEngine.disconnectNodeOutput(playerNode)
    playbackEngine.disconnectNodeOutput(playbackEngine.mainMixerNode)
    playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: playbackFormat)
    playbackEngine.connect(playbackEngine.mainMixerNode, to: playbackEngine.outputNode, format: nil)
    do {
        try playbackEngine.start()
        playerNode.play()
        let mixerOut = playbackEngine.mainMixerNode.outputFormat(forBus: 0)
        let deviceOut = playbackEngine.outputNode.outputFormat(forBus: 0)
        logInfo("playback engine started - mixer out: \(mixerOut), device out: \(deviceOut)")
    } catch {
        logError("playback engine failed to start: \(error)")
    }
}
startPlaybackEngine()
// A route/format change on the real output device can stop the engine out
// from under us (this is the normal AVAudioEngine contract - it does NOT
// auto-restart itself). Restart it whenever that happens instead of
// requiring a full SoundHelper relaunch to recover audio.
NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: playbackEngine, queue: .main) { _ in
    guard !playbackEngine.isRunning else { return }
    logInfo("playback engine configuration changed and stopped - restarting")
    startPlaybackEngine()
}

// Rebuilding the shared mixer means hard-stopping the old AudioDeviceIOProc
// and starting a new one - an abrupt stop/start mid-waveform (not at a
// zero-crossing) is audible as a click. Confirmed live: a 2-source test
// with 4 membership changes produced "a few pops/clicks". This ramps the
// final mixed output 0->1 over the first few callbacks of a new mixer,
// and signals the outgoing mixer to ramp 1->0 before teardown actually
// stops it, to turn those hard edges into short fades.
final class FadeState {
    var multiplier: Float32 = 0.0
    var fadingOut = false
    let step: Float32 = 0.2 // ~5 callbacks (~50ms at typical buffer sizes) to fade fully
}

final class SharedMixer {
    private var aggID: AudioObjectID = 0
    private var procID: AudioDeviceIOProcID?
    private var fadeState: FadeState?

    // taps: every currently-active tap, in a stable order. Safe to call
    // with the same set repeatedly (e.g. after a gain-only change) - only
    // actually tears down/rebuilds if the caller decides membership
    // changed (see pollOnce below); this method itself always rebuilds
    // when called, so callers must only call it on real membership change.
    //
    // Deliberately no kAudioAggregateDeviceMainSubDeviceKey / no
    // kAudioAggregateDeviceSubDeviceListKey here - this is a tap-only
    // aggregate with no physical hardware attached at all (confirmed
    // creatable via a standalone test before wiring this in). Its own
    // internal rate is derived purely from the tapped processes'
    // formats, so it's structurally insulated from any real device's
    // live renegotiation (e.g. Bluetooth's HFP/A2DP call-mode switch) -
    // nothing here ever reads or writes a real device's properties.
    func rebuild(taps: [(uuid: String, gain: GainBox)]) -> Bool {
        teardownCurrent()
        guard !taps.isEmpty else { return true }

        let tapListEntries = taps.map { [
            kAudioSubTapDriftCompensationKey as String: true,
            kAudioSubTapUIDKey as String: $0.uuid,
        ] }
        let aggDesc: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: "soundhelper-shared",
            kAudioAggregateDeviceUIDKey as String: "dev.robacarp.soundhelper.shared.\(UUID().uuidString)",
            kAudioAggregateDeviceIsPrivateKey as String: true,
            kAudioAggregateDeviceIsStackedKey as String: false,
            kAudioAggregateDeviceTapAutoStartKey as String: true,
            kAudioAggregateDeviceTapListKey as String: tapListEntries,
        ]
        var newAggID: AudioObjectID = 0
        guard AudioHardwareCreateAggregateDevice(aggDesc as CFDictionary, &newAggID) == noErr else {
            logError("mixer: aggregate creation failed")
            return false
        }
        if let aggRate = getNominalSampleRate(newAggID) {
            logInfo("mixer rebuild: tap-only aggregate rate=\(aggRate)")
        }

        let gainBoxes = taps.map { $0.gain } // same order as tapListEntries
        let newFadeState = FadeState()
        let audioQueue = DispatchQueue(label: "soundhelper.sharedaudio", qos: .userInitiated)
        var newProcID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&newProcID, newAggID, audioQueue) {
            (_, inInputData, _, _, _) in
            ioProcCallbackCount += 1
            let inBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inInputData))
            guard let firstBuf = inBuffers.first, firstBuf.mData != nil else { return }
            // Each tap's buffer is interleaved stereo Float32 (L0,R0,L1,R1,...);
            // mDataByteSize/4 counts total float values, i.e. 2x frame count.
            let sampleCount = Int(firstBuf.mDataByteSize) / 4
            let frameCount = sampleCount / 2
            guard frameCount > 0,
                  let mixBuffer = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: AVAudioFrameCount(frameCount)),
                  let channels = mixBuffer.floatChannelData
            else { return }
            mixBuffer.frameLength = mixBuffer.frameCapacity
            let leftPtr = channels[0]
            let rightPtr = channels[1]
            for f in 0..<frameCount { leftPtr[f] = 0; rightPtr[f] = 0 }
            for (i, buf) in inBuffers.enumerated() {
                guard i < gainBoxes.count, let inData = buf.mData else { continue }
                let g = gainBoxes[i].value
                let n = min(Int(buf.mDataByteSize) / 4, sampleCount)
                let inPtr = inData.bindMemory(to: Float32.self, capacity: n)
                var f = 0
                var s = 0
                while s + 1 < n {
                    leftPtr[f] += inPtr[s] * g
                    rightPtr[f] += inPtr[s + 1] * g
                    s += 2
                    f += 1
                }
            }
            if newFadeState.fadingOut {
                newFadeState.multiplier = max(0, newFadeState.multiplier - newFadeState.step)
            } else if newFadeState.multiplier < 1.0 {
                newFadeState.multiplier = min(1.0, newFadeState.multiplier + newFadeState.step)
            }
            let fm = newFadeState.multiplier
            if fm != 1.0 {
                for f in 0..<frameCount { leftPtr[f] *= fm; rightPtr[f] *= fm }
            }
            playerNode.scheduleBuffer(mixBuffer, completionHandler: nil)
        }
        guard status == noErr, let realProcID = newProcID else {
            logError("mixer: ioproc creation failed")
            AudioHardwareDestroyAggregateDevice(newAggID)
            return false
        }
        guard AudioDeviceStart(newAggID, realProcID) == noErr else {
            logError("mixer: start failed")
            AudioDeviceDestroyIOProcID(newAggID, realProcID)
            AudioHardwareDestroyAggregateDevice(newAggID)
            return false
        }
        aggID = newAggID
        procID = realProcID
        fadeState = newFadeState
        return true
    }

    func teardownCurrent() {
        if aggID != 0, let procID {
            fadeState?.fadingOut = true
            Thread.sleep(forTimeInterval: 0.08) // let a few callbacks ramp down first
            AudioDeviceStop(aggID, procID)
            AudioDeviceDestroyIOProcID(aggID, procID)
            AudioHardwareDestroyAggregateDevice(aggID)
        }
        aggID = 0
        procID = nil
        fadeState = nil
    }
}

struct ActiveTap {
    var tapID: AudioObjectID
    var uuid: String
    var name: String
    var key: String
    var gain = GainBox()
}

var activeTaps: [pid_t: ActiveTap] = [:]
// Tracks the output device last seen, purely to notice a genuine device
// switch (e.g. plugging in headphones) and nudge the playback engine in
// case it doesn't already pick that up on its own - AVAudioEngine is
// expected to follow the system default output automatically, but this
// is a cheap safety net given the capture side (SharedMixer) no longer
// tracks output devices at all. Same 2-consecutive-poll debounce as
// before, guarding against a single-poll blip.
var lastKnownOutputUID = getDefaultOutputDeviceUID() ?? ""
var candidateOutputUID: String?
var lastKnownSampleRate: Double?
let ownPID = ProcessInfo.processInfo.processIdentifier
let mixer = SharedMixer()
// Diagnostic: counts IOProc callbacks to check whether a tap-only
// aggregate (no real device attached) keeps its callback firing
// continuously, or stalls after some initial burst - not synchronized,
// exact precision doesn't matter for this.
var ioProcCallbackCount = 0
var lastLoggedCallbackCount = 0

// Processes never worth a slot: afplay fires (and exits) for every
// system notification ding, which would otherwise churn through a tap
// creation + mixer rebuild (and its fade-in/out) for something nobody
// wants to control from the deck.
let processNameBlacklist: Set<String> = ["afplay"]

func pollOnce() {
    var membershipChanged = false

    let deviceID = getDefaultOutputDeviceID()
    let currentOutputUID = deviceID.flatMap(getDeviceUID) ?? ""
    if currentOutputUID.isEmpty || currentOutputUID == lastKnownOutputUID {
        candidateOutputUID = nil
    } else if candidateOutputUID == currentOutputUID {
        logInfo("output device changed: \(lastKnownOutputUID) -> \(currentOutputUID)")
        lastKnownOutputUID = currentOutputUID
        candidateOutputUID = nil
        if !playbackEngine.isRunning {
            // The .AVAudioEngineConfigurationChange notification is the
            // primary restart path (see startPlaybackEngine's caller) -
            // reaching this means that didn't already catch it, worth
            // flagging distinctly rather than blending into routine info.
            logWarn("playback engine not running after output device change - restarting")
            startPlaybackEngine()
        }
    } else {
        candidateOutputUID = currentOutputUID // seen once - wait for a second consecutive poll to agree
    }

    if let deviceID, let rate = getNominalSampleRate(deviceID) {
        if let last = lastKnownSampleRate, last != rate {
            logDebug("output device nominal sample rate changed: \(last) -> \(rate) (diagnostic only - capture no longer depends on this)")
        }
        lastKnownSampleRate = rate
    }

    var activeNow: [pid_t: (AudioObjectID, String, String)] = [:]
    for obj in getProcessObjectList() {
        guard getIsRunningOutput(obj), let pid = getPID(obj), pid != ownPID else { continue }
        let comm = getProcessComm(pid)
        if processNameBlacklist.contains(comm) { continue }
        let displayName = getProcessDisplayName(pid, fallback: comm)
        activeNow[pid] = (obj, displayName, getBundleID(obj) ?? comm)
    }

    for pid in Array(activeTaps.keys) where activeNow[pid] == nil {
        let entry = activeTaps.removeValue(forKey: pid)!
        AudioHardwareDestroyProcessTap(entry.tapID)
        membershipChanged = true
        logInfo("tap removed: \(entry.name) (pid \(pid))")
    }

    for (pid, (obj, name, key)) in activeNow where activeTaps[pid] == nil {
        let desc = CATapDescription(stereoMixdownOfProcesses: [obj])
        desc.name = "soundhelper-\(pid)"
        desc.muteBehavior = .mutedWhenTapped
        var tapID: AudioObjectID = 0
        guard AudioHardwareCreateProcessTap(desc, &tapID) == noErr else {
            logWarn("tap creation failed: \(name) (pid \(pid))")
            continue
        }
        activeTaps[pid] = ActiveTap(tapID: tapID, uuid: desc.uuid.uuidString, name: name, key: key)
        membershipChanged = true
        logInfo("tap added: \(name) (pid \(pid))")
    }

    if membershipChanged {
        let entries = activeTaps.values.map { (uuid: $0.uuid, gain: $0.gain) }
        let ok = mixer.rebuild(taps: entries)
        logInfo("mixer rebuilt: ok=\(ok) tapCount=\(entries.count)")
    }
}

// MARK: - Hammerspoon bridge (WebSocket client -> ws://127.0.0.1:17722/)

final class HammerspoonBridge: NSObject, URLSessionWebSocketDelegate {
    private var session: URLSession!
    private var task: URLSessionWebSocketTask?
    private let url = URL(string: "ws://127.0.0.1:17722/")!
    var onSetGain: ((pid_t, Float32) -> Void)?

    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        connect()
    }

    private func connect() {
        let t = session.webSocketTask(with: url)
        task = t
        t.resume()
        receiveNext()
    }

    private func receiveNext() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message { self.handleMessage(text) }
                self.receiveNext()
            case .failure:
                self.task = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.connect() }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["type"] as? String == "setGain",
              let pid = obj["pid"] as? Int,
              let gain = obj["gain"] as? Double else { return }
        onSetGain?(pid_t(pid), Float32(gain))
    }

    func send(_ dict: [String: Any]) {
        guard task != nil, let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { _ in }
    }
}

let bridge = HammerspoonBridge()
bridge.onSetGain = { pid, gain in
    if let t = activeTaps[pid] {
        t.gain.value = gain
        // Fires on every repeat-tick while a volume button is held (as
        // often as every ~100-200ms from the Lua side), not just once per
        // press - debug-level, real anomalies (engine/player stopping)
        // are already surfaced at warn/info by the code that detects and
        // restarts them, not by this line.
        logDebug("setGain: \(t.name) (pid \(pid)) -> \(gain)")
    }
}

let pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    pollOnce()
    if !activeTaps.isEmpty {
        logDebug("ioproc callback count: \(ioProcCallbackCount) (+\(ioProcCallbackCount - lastLoggedCallbackCount) since last poll) engine.isRunning=\(playbackEngine.isRunning) player.isPlaying=\(playerNode.isPlaying)")
        lastLoggedCallbackCount = ioProcCallbackCount
    }
    var snapshot: [[String: Any]] = []
    for (pid, t) in activeTaps {
        snapshot.append(["pid": Int(pid), "name": t.name, "gain": Double(t.gain.value)])
    }
    bridge.send(["type": "snapshot", "processes": snapshot])
}
RunLoop.main.add(pollTimer, forMode: .common)

logInfo("soundhelper running (shared-mixer architecture, log level=\(currentLogLevel))")
RunLoop.main.run()
