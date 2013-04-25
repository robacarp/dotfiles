###strftime syntax:

  ruby: http://www.ruby-doc.org/core-1.9.3/Time.html#method-i-strftime
  php:  http://php.net/manual/en/function.strftime.php (no milliseconds)
    2012 12  - Jan  01  -  15    16 4  : 45 : 22 . 1234
    %Y   %y -  %B%b %m  -  %e    %H %l : %M : %S . %L

###Use rsync to resume interrupted scp transfer, or a fault tolerant rsync:
  rsync --archive --partial --progress --rsh=ssh user@host:remote_file local_file

###In rsync, archive means:
          --recursive
          --links (copy symlinks as symlinks, not derefrencing the file)
          --perms (preserve permissions)
          --times (preserve ctime, mtime, etc)
          --group --owner (preserve uid, gid)
          --devices  (su: preserve device files)
          --specials (preserve special files, sockets and the like)

###To make an iso from a cd/dvd:
  unmount the disk:
    diskUtil list #then find disk number
    diskUtil unmountDisk <disk number>

  create the image:
    dd if=/dev/disk# of=/path/to/file.iso bs=2048


##The ability to start some servers...I don't really want these running locally all the time.
#### MySQL
mysql.server start

#### elasticsearch
elasticsearch -f -D es.config=/usr/local/opt/elasticsearch/config/elasticsearch.yml
