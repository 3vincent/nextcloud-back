#!/bin/bash

### SETUP AREA

backupDestination=/home/{USERDIR}
nextcloudInstallation=/var/www/nextcloud
nextcloudData=/opt/nextcloud-data
apacheUser=www-data
mysqlUser=nxtclouddb
mysqlDatabase=nxtclouddb
mysqlPassword='123456789'
TMP_PATH=/tmp/

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#	1. Activate Maintenance Mode
#	2. Backup Installation Dir in Apache Web Folder
#	3. Backup Data Dir
# 4. Backup MySQL Database
#	5. Deactivate Maintenance Mode
# 6. Size, Location and Info-Output
#
#    Source mainly: https://www.c-rieger.de/nextcloud-sicherung-und-wiederherstellung/
#
#
#    Script does not check for available free space on the drive!
#    Have Fun
#
#    From remote do something like this:
#    $ scp -rp ${server-ip}:{source_dir_on_server} {destination_dir_on_local}
#
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function nextcloudMaintananceModeOn {
	sudo -u $apacheUser $nextcloudInstallation/occ maintenance:mode --on >/dev/null
}

function nextcloudMaintananceModeOff {
	sudo -u $apacheUser $nextcloudInstallation/occ maintenance:mode --off >/dev/null
}


### 0. Preparations
## Check if root

if [ "$EUID" -ne 0 ]
  then echo "***error *** Please run as root"
  exit
fi

## check if pv, tar, gzip and du exists on the system

declare -a CLI_TOOLS

CLI_TOOLS=(
  "pv"
  "tar"
  "gzip"
	"du"
)

for tool in ${CLI_TOOLS[@]}
do
	if [ ! $(which $tool) ]; then
		echo "***error *** $tool does not exist on this system. Please install it! Exiting..."
    exit
	fi
done


## Create Backup Directory TARGET

# fetch current date as YYYYMMDD
DATESTAMP=$(date +%Y-%m-%d) 

backupDestination="$backupDestination/nextcloud_backup_$DATESTAMP"

if [ -d $backupDestination ]; then
	echo "*** error*** Backup Location: $backupDestination already exists!"
	exit
fi

mkdir $backupDestination

echo "############## Nextcloud Backup 101 ##############"


###	1. Activate Maintenance Mode in nextcloud

if (nextcloudMaintananceModeOn); then
	echo "1. Turn Nextcloud Maintenance Mode ON"
else
	echo "***error *** Nextcloud occ Maintenance Mode was not successfull!"
	exit
fi


###	2. Backup installation directories and files and move to backupDestination

# set default size to zero for counting the 
# size of the nextcloud installation directory
sizeOfDir=0 

if [ -d "$backupDestination" ] && [ -d "$nextcloudInstallation" ]; then
	echo "2. Creating Backup of Installation Directory $nextcloudInstallation ..."
	sizeOfDir=$(du -sk "$nextcloudInstallation" | cut -f 1)
	tar -cpf - -C "$nextcloudInstallation" . | pv --size ${sizeOfDir}k -p --timer --rate --bytes | gzip -c > "$backupDestination/nextcloud-InstallationDir_$DATESTAMP.tar.gz"
elif [ ! -d "$backupDestination" ]; then
	echo "***error *** Directory not found: $backupDestination"
	nextcloudMaintananceModeOff
	exit 1
elif [ ! -d "$nextcloudInstallation" ]; then
	echo "***error *** Directory not found: $nextcloudInstallation"
  nextcloudMaintananceModeOff
	exit 1
fi
echo ""


###	3. Backup Data Directory

if [ -d "$backupDestination" ] && [ -d "$nextcloudData" ]; then
        echo "3. Creating Backup of Data Directory $nextcloudData ..."
	sizeOfDir=$(du -sk "$nextcloudData" | cut -f 1)
        tar -cpf - -C "$nextcloudData" . | pv --size ${sizeOfDir}k -p --timer --rate --bytes | gzip -c > "$backupDestination/nextcloud-DataDir_$DATESTAMP.tar.gz"
elif [ ! -d "$backupDestination" ]; then
        echo "***error *** Directory not found: $backupDestination"
				nextcloudMaintananceModeOff
        exit 1
elif [ ! -d "$nextcloudInstallation" ]; then
        echo "***error *** Directory not found: $nextcloudInstallation"
				nextcloudMaintananceModeOff
        exit 1
fi


###	4. MySql Backup

if [ ! -d $backupDestination ]; then
	echo "***error *** Directory does not exist: $backupDestination"
	nextcloudMaintananceModeOff
	exit 1
fi

echo "4. Creating Backup of MySQL Database $mysqlDatabase ..."
mysqldump --single-transaction -h localhost -u $mysqlUser -p $mysqlDatabase --password=$mysqlPassword > ${TMP_PATH}/nextcloud_db_backup_tempfile_${DATESTAMP}.sql
echo "...compressing database dump"
gzip ${TMP_PATH}/nextcloud_db_backup_tempfile_${DATESTAMP}.sql > "$backupDestination/nextcloud_mysqlDatabase_${DATESTAMP}.sql.gz"
rm ${TMP_PATH}/nextcloud_db_backup_tempfile_${DATESTAMP}.sql



###	5. Deactivate Maintenance Mode

if (nextcloudMaintananceModeOff); then
	echo "5. Nextcloud Maintenance Mode OFF"
else
	echo "***error *** Something went wrong with turning nextcloud maintenance mode off"
fi


###	6. Size, Location, Infomation Output

backupSize=$(du -csh $backupDestination | grep total | awk '{ print $1 }')
echo ""
echo "Done."
echo "Your Backup Information:"
echo "Location:      $backupDestination"
echo "Size:          $backupSize"
