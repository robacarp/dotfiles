require 'irb/ext/save-history'
#History configuration
IRB.conf[:SAVE_HISTORY] = 300
IRB.conf[:HISTORY_FILE] = "#{ENV['HOME']}/.irb-history"

