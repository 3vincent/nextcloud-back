# nextcloud-backup

This bash script makes a full backup of a nextcloud installation on a LAMP Stack Server. The script is following the [official guide](https://docs.nextcloud.com/server/latest/admin_manual/maintenance/backup.html).

There are a few requirements:

- `tar` `gzip` `pv` `du` `php` need to be installed on your system
- Depending on your database configuration you will also need to have `mysqldump` or `pg_dump` installed
- If you want to use the encryption feature you'll also need GnuPG: `gpg` installed

## Functionality

The script makes a Backup of your nextcloud Installation by putting all files and databases in tar.bz archives:

- Installation directory (i.e. `/var/www/nextcloud`)
- Data directory (i.e. `/opt/nextcloud-data`)
- MySQL or Postgresql database

The backup is moved to the backup location that is set in the config file (`backupDestination=''`).

For security reasons, the database password is passed as an environment variable.
This variable can be set on execution: `NEXTCLOUDDATABASEPW=mypassword ./nextcloud-backup.sh`

## Installation

    git clone https://github.com/3vincent/nextcloud-backup.git

## Setup

After downloading, make sure the script is executable or run:

    chmod +x nextcloud-backup.sh

Copy the example config file to your users home folder that will execute the script, i.e. `~/.nextcloud-backup.config`

    nano ~/.nextcloud-backup.config

## Configuration for your environment

All settings the script needs, directory paths, user names can be set in a config file.
By default the config example file is located in the directory `nextcloud-backup.config.example`.

You can copy the example file

    $ cp nextcloud-backup.config.example ~/.nextcloud-backup.config

Then edit the config file:

    $ nano ~/.nextcloud-backup.config

Change these values according to your installation:

    backupDestination=/some/directory/
    nextcloudInstallation=/var/www/nextcloud
    nextcloudData=/opt/nextcloud-data
    apacheUser=www-data
    databaseType=postgres
    databaseUser=nxtclouddb
    databaseDatabaseName=nxtclouddb
    databasePassword=''
    mysql4byte=1
    encryption=1
    encryptionPassword='some-possibly-long-passphrase'
    TMP_PATH=/tmp

- `backupDestination`: A directory that should exists. Make sure you have enough disk space. The script does not check this for you.
- `nextcloudInstallation`: Directory where your Nextcloud installation lives, e.g. /var/www/nextcloud
- `nextcloudData`: Directory where Nextcloud stores your user data, e.g. /opt/nextcloud-data
- `apacheUser`: The user that runs your php or php-fpm environment
- `databaseType`: Can be either **mysql** or **postgres**
- `databaseUser`: The name of your Nextcloud MySQL or Postgresql database user
- `databaseDatabaseName`: The name of your Nextcloud MySQL or Postgresql database
- `databasePassword`: Can/should be left empty when the password is passed as an **ENV_VAR**. See examples below.
- `mysql4byte`: Can be **1** (true) or **0** (false). It determines if your MySQL database uses 4-byte support. Standard is true(1). If you use postgresql you can ignore this.
- `encryption`: Can be either **1** (true) or **0** (false) to turn encryption on (=true=1) or off(=false=0)
- `encryptionPassword`: Can/should be left empty when the password is passed as an **ENV_VAR**. See examples below.

## Environment Variable vs. Config Variable

1. You can either pass your database password and encryption password as an environment variable at execution time, like this `NEXTCLOUDDATABASEPW=mypassword NCFILEENCRYPTIONPW=myverysecurepassword ./nextcloud-backup.sh`.

2. Or you can set it up in your config file: `databasePassword='mypassword'` and `encryptionPassword='myverysecurepassword'`.

If you set the password as environment variable at exection (1) it overwrites the password that is set in the config file (2).

If the password is set in the config file (2), it mentions this at startup.

If both options are empty (1)+(2), the script will quit.

## Encryption

The encryption is done with a passphrase and with gpg using the AES256 algorithm.
Encryption needs to be enabled in the config file with

    ...
    encryption=1
    ...

you also need to add a passphrase that is used for the encryption. Please use a secure passphrase.

     ...
    encryption=1
    encryptionPassword='myVerySecurePasswordOrPassphrase'
    ...

When enabled, the script will encrypt all files in the current backup directory with the given password, e.g.

    nextcloud_backup_2023-02-12_10-49-11
        -> 2023-02-12_10-49-12_nextcloud_postgresDatabase.sql.gz.gpg
        -> 2023-02-12_10-49-18_nextcloud-DataDir.tar.gz.gpg
        -> 2023-02-12_10-56-41_nextcloud-InstallationDir.tar.gz.gpg

To decrypt a specific file you can use this command:

    $ gpg --output 2023-02-12_10-49-12_nextcloud_postgresDatabase.sql.gz --decrypt 2023-02-12_10-49-12_nextcloud_postgresDatabase.sql.gz.gpg

GnuPG will then ask you for the passwort in a prompt.

## Execution Examples

Run from the local system with Database Password as Env var:

    NEXTCLOUDDATABASEPW='mydatabasepassword' ./nextcloud-backup.sh

Run from a remote system via ssh. The database password is passed from the local system to the remote server with ssh:

    ssh -t {username}@{serverip} 'export NEXTCLOUDDATABASEPW='mysqlpassword'; nextcloud-backup.sh'

## Copy from remote to local

To copy backups from a remote system to your local machine, you can use a command like this

    scp -rp ${server-ip}:{source_dir_on_server} {destination_dir_on_local}

## Sources

[1] Enabling 4-byte support in nextcloud, [https://docs.nextcloud.com/server/latest/admin_manual/configuration_database/mysql_4byte_support.html](https://docs.nextcloud.com/server/latest/admin_manual/configuration_database/mysql_4byte_support.html)

[2] Nextcloud Backup, [https://docs.nextcloud.com/server/latest/admin_manual/maintenance/backup.html](https://docs.nextcloud.com/server/latest/admin_manual/maintenance/backup.html)

## Note

- The script does not check for available disk space. Make sure you have enough disk space before running this.
- This script has been tested with Nextcloud 23, Nextcloud 24 and Nextcloud 25
- This script was testet and fixed according to [shellcheck.net](https://shellcheck.net)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html#s1.1-which-shell-to-use) was very helpfull
