#!/bin/bash

backupLocation=/home/{USERDIR}
nextcloudInstallation=/var/www/nextcloud
nextcloudData=/opt/nextcloud-data
apacheUser=www-data
mysqlUser=nxtclouddb
mysqlDatabase=nxtclouddb
mysqlPassword='123456789'
backupDate=$(date +%Y%m%d) # dont change this !
sizeOfDir=0 # dont change this !

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#	1. Activate Maintenance Mode
#	2. Backup Installation Dir in Apache Web Folder
#	3. Backup Data Dir
# 	4. Backup MySQL Database
#	5. Deactivate Maintenance Mode
# 	6. Size, Location and Info-Output
#
#   Source mainly: https://www.c-rieger.de/nextcloud-sicherung-und-wiederherstellung/
#
#
#   Script does not check for available free space on the drive!
#   Have Fun
#
#   From remote do something like this:
#   $ scp -rp ${server-ip}:{source_dir_on_server} {destination_dir_on_local}
#
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


#       0. Preparations
# Check if root

if [ "$EUID" -ne 0 ]
  then echo "***error *** Please run as root"
  exit
fi

# check if pv, tar, gzip
if [ $(which pv) ]; then echo "true"; fi
if [ ! $(which pv) ]; then
	echo "***error *** /usr/bin/pv does not exist. Please install it!"
	exit
fi
if [ ! $(which /bin/tar) ]; then
	echo "***error *** /bin/tar does not exist. Please install it!"
        exit
fi
if [ ! $(which /bin/gzip) ]; then
        echo "***error *** /bin/gzip does not exist. Please install it!"
        exit
fi
if [ ! $(which /usr/bin/du) ]; then
        echo "***error *** /usr/bin/du does not exist. Please install it!"
        exit
fi

# Create Backup Directory TARGET

backupLocation="$backupLocation/nextcloud_backup_$backupDate"

if [ ! -d $backupLocation ]; then
	mkdir $backupLocation
else
	echo "*** error*** Backup Location: $backupLocation already exists!"
	exit
fi

echo "############## Nextcloud Backup 101 ##############"


#	1. Activate Maintenance Mode in nextcloud

if (sudo -u $apacheUser $nextcloudInstallation/occ maintenance:mode --on >/dev/null); then
	echo "1. Nextcloud Maintenance Mode ON"
else
	echo "***error *** Nextcloud occ Maintenance Mode was not successfull!"
	exit
fi


#	2. Backup Installation Dir in Apache Web Folder

if [ -d "$backupLocation" ] && [ -d "$nextcloudInstallation" ]; then
	echo "2. Creating Backup of Installation Directory $nextcloudInstallation ..."
	sizeOfDir=$(du -sk "$nextcloudInstallation" | cut -f 1)
	tar -cpf - -C "$nextcloudInstallation" . | pv --size ${sizeOfDir}k -p --timer --rate --bytes | gzip -c > "$backupLocation/nextcloud-InstallationDir_$backupDate.tar.gz"
elif [ ! -d "$backupLocation" ]; then
	echo "***error *** Directory not found: $backupLocation"
	sudo -u $apacheUser $nextcloudInstallation/occ maintenance:mode --off
	exit 1
elif [ ! -d "$nextcloudInstallation" ]; then
	echo "***error *** Directory not found: $nextcloudInstallation"
	sudo -u $apacheUser $nextcloudInstallation/occ maintenance:mode --off
	exit 1
fi
echo ""

#	3. Backup Data Directory

if [ -d "$backupLocation" ] && [ -d "$nextcloudData" ]; then
        echo "3. Creating Backup of Data Directory $nextcloudData ..."
	sizeOfDir=$(du -sk "$nextcloudData" | cut -f 1)
        tar -cpf - -C "$nextcloudData" . | pv --size ${sizeOfDir}k -p --timer --rate --bytes | gzip -c > "$backupLocation/nextcloud-DataDir_$backupDate.tar.gz"
elif [ ! -d "$backupLocation" ]; then
        echo "***error *** Directory not found: $backupLocation"
        sudo -u $apacheUser $nextcloudInstallation/occ maintenance:mode --off
        exit 1
elif [ ! -d "$nextcloudInstallation" ]; then
        echo "***error *** Directory not found: $nextcloudInstallation"
        sudo -u $apacheUser $nextcloudInstallation/occ maintenance:mode --off
        exit 1
fi


#	4. MySql Backup

if [ ! -d $backupLocation ]; then
	echo "***error *** Directory does not exist: $backupLocation"
	sudo -u $apacheUser $nextcloudInstallation/occ maintenance:mode --off
	exit 1
else
        echo "4. Creating Backup of MySQL Database $mysqlDatabase ..."
	mysqldump --single-transaction \
	    -h localhost -u $mysqlUser -p $mysqlDatabase \
	    --password=$mysqlPassword | gzip > "$backupLocation/nextcloud_mysqlDatabase_$backupDate.sql.gz"
fi


#	5. Deactivate Maintenance MOde

if (sudo -u $apacheUser $nextcloudInstallation/occ maintenance:mode --off >/dev/null); then
	echo "5. Nextcloud Maintenance Mode OFF"
else
	echo "***error *** Something went wrong with turning nextcloud maintenance mode off"
fi



#	6. Size, Location, Infomation Output

backupSize=$(du -csh $backupLocation | grep total | awk '{ print $1 }')
echo ""
echo "Done."
echo "Your Backup Information:"
echo "Location:      $backupLocation"
echo "Size:          $backupSize"
# echo "Duration:		$backupDuration"
