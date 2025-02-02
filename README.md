# Rsync-Incr 

**rsync-incr** is a linux wrapper shell (bash) script around [rsync](http://samba.anu.edu.au/ftp/rsync/rsync.html) to perform automated, unattended, incremental, disk to disk backups,  automatically removing old backups to make room for new ones. It  produces standard mirror copies browsable and restorable without  specific tools.I have been using it in production daily at work and at  home since 2004.

### Goals 

I wanted to have a backup system with the following properties: 

-  **standard** based on standard tools (rsync), and restorable with only standard tools.
-  **simple** as possible.
-  **automatable** to be run daily (or more) by  crontab, managing error conditions reliably so we can mail on errors,  and making automatically room for new backups.

## More info

- Its web page and documentation at https://colas.nahaboo.net/Code/RsyncIncr
- Installation: just copy the bash script [rsync-incr](rsync-incr) into your PATH (e.g, `/usr/local/bin`)
- License: GPL V3

