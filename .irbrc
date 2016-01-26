require 'irb/ext/save-history'
#History configuration
IRB.conf[:SAVE_HISTORY] = 300
IRB.conf[:HISTORY_FILE] = "#{ENV['HOME']}/.irb-history"


module Robocarp
  # Send stuff to the system clipboard (osx)
  def copy stuff
     IO.popen('pbcopy', 'w') { |f| f << stuff.to_s }
  end

  def paste
     IO.popen('pbpaste', 'r') { |f| f.gets }
  end
end

extend Robocarp
