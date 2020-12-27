# nextcloud-backup
Bash Script for Nextcloud Backup on a Debian 9/Apache Server  
  
This script is designed for my personal usage. But you can easily adapt it for your own Nextcloud Installation. 
There are a few requirements: `tar` `gzip` `pv` `du` must be installed on your system.  
  
## Functionality  
The script makes a Backup of your nextcloud Installation by putting all files and databases in tar.bz archives:   

- Installation directory (i.e. `/var/www/nextcloud`)
- Data directory (i.e. `/opt/nextcloud-data`)
- MySQL database


## Modification for Personal Use

Change these variables for personal use:
``` - backupLocation=/home/{USERDIR}
- nextcloudInstallation=/var/www/nextcloud
- nextcloudData=/opt/nextcloud-data
- apacheUser=www-data
- mysqlUser=nxtclouddb
- mysqlDatabase=nxtclouddb
- mysqlPassword='123456789'
```
