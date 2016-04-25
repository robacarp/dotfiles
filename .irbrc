require 'irb/ext/save-history'
require 'irb/completion'
require 'pp'

#History configuration
IRB.conf[:SAVE_HISTORY] = 300
IRB.conf[:HISTORY_FILE] = "#{ENV['HOME']}/.irb-history"
IRB.conf[:AUTO_INDENT]=true

module Robocarp
  # Send stuff to the system clipboard (osx)
  def copy stuff
     IO.popen('pbcopy', 'w') { |f| f << stuff.to_s }
     stuff
  end

  def paste
     IO.popen('pbpaste', 'r') { |f| f.gets }
  end

  def methods thing
    m = case thing
    when Module
      thing.methods.sort - Module.methods
    when Class
      thing.methods.sort - Class.methods
    else
      thing.methods.sort - Object.methods
    end
  end

  def details thing
    meths = methods thing
    Hash[meths.map {|m| [m, thing.method(m)] }]
  end

  def local_methods thing
    meths = details thing
    meths.keep_if do |k,v|
      v.source_location && v.source_location.first =~ /#{Dir.pwd}/
    end

    meths.keys
  end
  alias_method :lmethods, :local_methods

end

extend Robocarp

irbrc = File.join(Dir.pwd, ".irbrc")
load irbrc if File.exists?(irbrc)
