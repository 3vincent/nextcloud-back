# nextcloud-backup

This bash script makes a full backup of a nextcloud installation on a LAMP Stack Server. The script is following the [official guide](https://docs.nextcloud.com/server/latest/admin_manual/maintenance/backup.html).

There are a few requirements: `tar` `gzip` `pv` `du` `mysqldump` need to be installed on your system.

## Installation

    git clone https://github.com/3vincent/nextcloud-backup.git

## Functionality

The script makes a Backup of your nextcloud Installation by putting all files and databases in tar.bz archives:

- Installation directory (i.e. `/var/www/nextcloud`)
- Data directory (i.e. `/opt/nextcloud-data`)
- MySQL database

The backup is moved to the backup location that is set in the SETUP Area (`$backupDestination`).

For security reasons, the mySQL Password is passed as an environment variable.
This variable can be set on execution: `NEXTCLOUDMYSQLPW=mypassword ./nextcloud-backup.sh`

## Setup

After downloading, make sure the script is executable or run:

    chmod +x nextcloud-backup.sh

Copy the example config file to your users home folder that will execute the script, i.e. `~/.nextcloud-backup.config`

    nano ~/.nextcloud-backup.config

## Modification for your environment

All settings the script needs, directory paths, user names can be set in a config file.
By default the config file is located in `~/.nextcloud-backup.config`

Change these variables according to your installation:

    backupDestination=someDirectory
    nextcloudInstallation=/var/www/nextcloud
    nextcloudData=/opt/nextcloud-data
    apacheUser=www-data
    mysqlUser=nxtclouddb
    mysqlDatabase=nxtclouddb
    mysqlPassword=''
    mysql4byte=1
    TMP_PATH=/tmp

- `backupDestination`: A directory that should exists. Make sure you have enough disk space. The script does not check this for you.
- `nextcloudInstallation`: Directory where your Nextcloud installation lives, e.g. /var/www/nextcloud
- `nextcloudData`: Directory where Nextcloud stores your user data, e.g. /opt/nextcloud-data
- `apacheUser`: The user that runs your php or php-fpm environment
- `mysqlUser`: The name of your Nextcloud MySQL database user
- `mysqlDatabase`: The name of your Nextcloud MySQL database
- `mysqlPassword`: Can/should be left empty when the password is passed as an **ENV_VAR.** Examples see below.
- `mysql4byte`: Can be true(1) or false(0). It determines if your MySQL database uses 4-byte support. Standard is true(1).

## Environment Variable vs. Config Variable

1. You can either pass your mySQL password as an environment variable at execution time, like this `NEXTCLOUDMYSQLPW=mypassword ./nextcloud-backup.sh`.

2. Or you can set it up in your config file. (`mysqlPassword=''`).

If you set the password as environment variable at exection (1) it overwrites the password that is set in the config file (2).

If the password is set in the config file (2), it mentions this at startup.

If both options are empty (1)+(2), the script will quit.

## Execution Examples

Run from the local system with MySQL Password as Env var:

    NEXTCLOUDMYSQLPW='mysqlpassword' ./nextcloud-backup.sh

Run from a remote system via ssh. The mySQL Password is passed from the local system to the remote server with ssh:

    ssh -t {username}@{serverip} 'export NEXTCLOUDMYSQLPW='mysqlpassword'; nextcloud-backup.sh'

## Copy from remote to local

To copy backups from a remote system to your local machine, you can use a command like this

    scp -rp ${server-ip}:{source_dir_on_server} {destination_dir_on_local}

## Sources

[1] Enabling 4-byte support in nextcloud, [https://docs.nextcloud.com/server/latest/admin_manual/configuration_database/mysql_4byte_support.html](https://docs.nextcloud.com/server/latest/admin_manual/configuration_database/mysql_4byte_support.html)

[2] Nextcloud Backup, [https://docs.nextcloud.com/server/latest/admin_manual/maintenance/backup.html](https://docs.nextcloud.com/server/latest/admin_manual/maintenance/backup.html)

## Note

- The script does not check for available disk space. Make sure you have enough disk space before running this.
- This script was testet and fixed according to [shellcheck.net](https://shellcheck.net)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html#s1.1-which-shell-to-use) was very helpfull
