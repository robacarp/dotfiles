function colors -d "Prints out a list of color codes for quick reference"
ruby -e '
  pre = "\033["
  post = "m"
  clear = "\033[0m"
  [30,31,32,33,34,35,36,37].each do |n|
    print pre + n.to_s + post
    print n
    print ">"

    [40,41,42,43,44,45,46,47].each do |m|
      print pre + m.to_s + post
      print m
      print " "
    end
    puts clear
  end

  print pre + "1" + post + "1 - Bold"
  puts clear
  print pre + "4" + post + "4 - Underline"
  puts clear
  print pre + "5" + post + "5 - Blink"
  puts clear
  print pre + "7" + post + "7 - Reverse"
  puts clear
  print pre + "8" + post + "8 - Concealed"
  print clear
  puts "<-- 8 - concealed"
'
end
