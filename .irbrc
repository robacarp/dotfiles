require 'irb/completion'
require 'pp'

#History configuration
IRB.conf[:SAVE_HISTORY] = 300
IRB.conf[:HISTORY_FILE] = "#{ENV['HOME']}/.irb-history"
IRB.conf[:AUTO_INDENT]=true

begin
  require 'awesome_print'

  def ap object = nil, options={ indent: -2 }
    super
  end
rescue LoadError

  def ap object, options={}
    pp object
  end
end

module Robocarp
  # Send stuff to the system clipboard (osx)
  def copy stuff
     IO.popen('pbcopy', 'w') { |f| f << stuff.to_s }
     stuff
  end

  def paste
     IO.popen('pbpaste', 'r') { |f| f.gets }
  end

  def history search=nil, limit=19
    history = IRB::HistorySavingAbility::HISTORY.to_a
    history.pop # remove current command

    filtered_history = case search
    when Regexp
      history.select {|e| e =~ search}
    when String
      history.map {|s| [ levenshtein_distance(s, search), s ] }
             .sort {|a,b| b.first <=> a.first }
             .map {|s| s[1] }
    when NilClass
      history
    end

    filtered_history.last(limit).uniq
  end

  # credit: 2016-05-18 http://rosettacode.org/wiki/Levenshtein_distance#Ruby
  def levenshtein_distance(a, b)
    a, b = a.downcase, b.downcase
    costs = Array(0..b.length) # i == 0
    (1..a.length).each do |i|
      costs[0], nw = i, i - 1  # j == 0; nw is lev(i-1, j)
      (1..b.length).each do |j|
        costs[j], nw = [costs[j] + 1, costs[j-1] + 1, a[i-1] == b[j-1] ? nw : nw + 1].min, costs[j]
      end
    end
    costs[b.length]
  end

end

extend Robocarp

irbrc = File.join(Dir.pwd, ".irbrc")
load irbrc if File.exist?(irbrc) unless irbrc == __FILE__
IRB.conf[:USE_AUTOCOMPLETE] = false
