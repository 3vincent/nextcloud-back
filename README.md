# nextcloud-backup
  
This bash script makes a full backup of a nextcloud installation on a LAMP Stack Sever.

There are a few requirements: `tar` `gzip` `pv` `du` `mysqldump` need to be installed on your system.  
  
## Functionality  

The script makes a Backup of your nextcloud Installation by putting all files and databases in tar.bz archives:   

- Installation directory (i.e. `/var/www/nextcloud`)
- Data directory (i.e. `/opt/nextcloud-data`)
- MySQL database

The backup is moved to the backup location that is set in the SETUP Area (`$backupDestination`).

For security reasons, the mySQL Password is passed as an environment variable.
This variable can be set on execution: `NEXTCLOUDMYSQLPW=mypassword ./nextcloud-backup.sh`

## Modification for Personal Use

Change these variables for personal use:
``` - backupDestination=/home/{USERDIR}
- nextcloudInstallation=/var/www/nextcloud
- nextcloudData=/opt/nextcloud-data
- apacheUser=www-data
- mysqlUser=nxtclouddb
- mysqlDatabase=nxtclouddb
- mysqlPassword='123456789'
```

## Setup

After downloading, make the script executable

    chmod +x nextcloud-backup.sh

Edit the script with your favorite editor, to set your preferences in the top of the file `SETUP AREA`:

    nano nextcloud-backup.sh

## Execution Examples
Run from the local system with MySQL Password as Env var:

    NEXTCLOUDMYSQLPW='mysqlpassword' ./nextcloud-backup.sh

Run from a remote system via ssh. The mySQL Password is passed from the local system to the remote server with ssh:

    ssh -t {username}@{serverip} 'export NEXTCLOUDMYSQLPW='mysqlpassword'; nextcloud-backup.sh'

## Note

- The script does not check for available disk space. Make sure you have enough disk space before running this.
