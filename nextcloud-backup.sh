#!/bin/bash

# nextcloud backup script
# github.com/3vincent/nextcloud-backup

### SETUP AREA
###
echo ""

mysqlPassword='' #set default
mysql4byte=1  #set default
TMP_PATH=/tmp #set default

CONFIGFILE=~/.nextcloud-backup.config
CONFIGFILEREAD=false
SCRIPTPATH=$(realpath "$0" | sed 's|\(.*\)/.*|\1|')

###
### END SETUP AREA

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#    NEXTCLOUD BACKUP 101
#
#    1. Activate Maintenance Mode
#    2. Backup MySQL Database
#    3. Backup Data Dir
#    4. Backup Installation Dir in Apache Web Folder
#    5. Deactivate Maintenance Mode
#    6. Size, Location and Info-Output
#
#    Script does not check for available free space on the drive!
#    Have Fun
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# if any errors quit
set -e

# Function: Set nextcloud maintenance mode on or off
nextcloudMaintenanceSetMode() {
  modeSet="${1}"

  if [ "$modeSet" != "on" ] && [ "$modeSet" != "off" ]; then
    echo "*** Error: Mode must be either on or off!"
    echo "exiting..."
    exit 1;
  fi

  echo "Turn Nextcloud Maintenance Mode: ${modeSet}"
  sudo -u $apacheUser $nextcloudInstallation/occ maintenance:mode --"${modeSet}"

  # if previous command ended without error
  if [ "$?" -eq "0" ]; then
    echo "....Done"
  else
    echo "*** Error: Setting maintenance mode to ${modeSet} failed"
    echo "*** exiting..."
    exit;
  fi
}

# function exit hook, automatically called on exit
exitHook() {
  echo "@@@ running exit hook..."
  if [[ $CONFIGFILEREAD = true ]]; then
    nextcloudMaintenanceSetMode off
  fi
}

trap exitHook EXIT

#########################################################
### 0. Preparations
###

## Check if root

if [ "$EUID" -ne 0 ]; then
  echo "*** error *** Please run as root"
  exit
fi

# Load setup variables from config file

if [[ -f "$CONFIGFILE" ]]; then
  source "$CONFIGFILE"
  CONFIGFILEREAD=true
elif [[ -f ${SCRIPTPATH}/nextcloud-backup.config.example ]]; then
  echo "*** error no config file found"
  echo "=> Please create a config file at the location $CONFIGFILE"
  echo "$ cp ./nextcloud-backup.config.example $CONFIGFILE"
  echo "exiting..."
  exit 1;
else
  echo "*** error no config file found"
  echo ""
  echo "=> Please create a config file at the location $CONFIGFILE"
  echo "exiting..."
  exit 1;
fi

# check if all user set paths really exist

declare -a USERDIRPATHS

USERDIRPATHS=(
  $backupDestination
  $nextcloudInstallation
  $nextcloudData
  $TMP_PATH
)

for usersetpath in "${USERDIRPATHS[@]}"; do
  if [ ! -d "$usersetpath" ]; then
    echo "***error *** $usersetpath does not exist on this system. Please check your setting in the $CONFIGFILE"
    echo "exiting..."
    exit 1;
  fi
done

# check if the environment variable for the mysql Password is set
# if not use the password that was set in the config file
# env var password is always preferred to the one set inside the file

if [ -z "$NEXTCLOUDMYSQLPW" ] && [ -z "$mysqlPassword" ]; then
  echo "no mysql password set"
  echo "exiting..."
  exit
fi

if [ -n "$NEXTCLOUDMYSQLPW" ]; then
  mysqlPassword=$NEXTCLOUDMYSQLPW
fi

if [ -z "$NEXTCLOUDMYSQLPW" ] && [ -n "$mysqlPassword" ]; then
  echo "Using mySQL Password that was set in the file"
fi

## check if cli tool exist on the system

declare -a CLI_TOOLS

CLI_TOOLS=(
  "pv"
  "tar"
  "gzip"
  "du"
  "mysqldump"
  "php"
)

for tool in "${CLI_TOOLS[@]}"; do
  if [ ! "$(which "$tool")" ]; then
    echo "***error *** $tool does not exist on this system. Please install it! Exiting..."
    exit 1;
  fi
done

# fetch current date as YYYYMMDD
DATESTAMP() { date +%Y-%m-%d_%H-%M-%S; }

# Create Backup Directory TARGET
backupDestination="$backupDestination/nextcloud_backup_$(DATESTAMP)"

if [ -d "$backupDestination" ]; then
  echo "*** error*** Directory: $backupDestination already exists!"
  exit
fi

mkdir "$backupDestination"

# check if backup destination exists after creation

if [ ! -d "$backupDestination" ]; then
  echo "***error *** Directory does not exist: $backupDestination"
  exit 1
fi

# check if mysql4byte SETUP VAR is set to true or false

if [ $mysql4byte -ne 1 ] && [ $mysql4byte -ne 0 ]; then
  echo "*** Error: $mysql4byte has to be either true or false"
  exit 1;
fi

# check if installation directory is valid in SETUP VAR

if [ ! -d "$nextcloudInstallation" ]; then
  echo "***error *** Directory not found: $nextcloudInstallation"
  exit 1
fi

# check if data directory is valid in SETUP VAR

if [ ! -d "$nextcloudData" ]; then
  echo "***error *** Directory not found: $nextcloudData"
  exit 1
fi


#########################################################
### STARTER

echo "############## Nextcloud Backup 101 ##############"

#########################################################
### 1. Activate Maintenance Mode in nextcloud
###

nextcloudMaintenanceSetMode on

#########################################################
### 2. MySQL Backup
###

# write mysql config file that is used to hide the password from the process list

mysqlConfigFile=${TMP_PATH}/.mylogin.cnf

printf "[mysqldump]\nuser=%s\npassword=%s\n" "${mysqlUser}" "${mysqlPassword}" > $mysqlConfigFile

chmod 600 ${mysqlConfigFile}

# prepare backup

echo "Creating Backup of MySQL Database $mysqlDatabase ..."
FIXEDDATESTAMP=$(DATESTAMP)

if [ $mysql4byte -eq 1 ]; then
  mysqldump --defaults-file=${mysqlConfigFile} \
  --default-character-set=utf8mb4 \
  --single-transaction \
  -h localhost $mysqlDatabase > ${TMP_PATH}/"${FIXEDDATESTAMP}"_nextcloud_db_backup_tempfile.sql
fi

if [ $mysql4byte -eq 0 ]; then
  mysqldump --defaults-file=${mysqlConfigFile} \
  --single-transaction \
  -h localhost $mysqlDatabase > ${TMP_PATH}/"${FIXEDDATESTAMP}"_nextcloud_db_backup_tempfile.sql
fi

echo "...compressing database dump"
gzip < ${TMP_PATH}/"${FIXEDDATESTAMP}"_nextcloud_db_backup_tempfile.sql > "$backupDestination/${FIXEDDATESTAMP}_nextcloud_mysqlDatabase.sql.gz"
rm ${TMP_PATH}/"${FIXEDDATESTAMP}"_nextcloud_db_backup_tempfile.sql
rm ${mysqlConfigFile}

echo "...okay"
echo ""

#########################################################
### 3. Backup Data Directory
###

if [ -d "$backupDestination" ] && [ -d "$nextcloudData" ]; then
  echo "Creating Backup of Data Directory $nextcloudData ..."
  sizeOfDir=$(du -sk "$nextcloudData" | cut -f 1)
  tar -cpf - -C "$nextcloudData" . \
    | pv --size "${sizeOfDir}"k -p --timer --rate --bytes \
    | gzip -c > "$backupDestination/$(DATESTAMP)_nextcloud-DataDir.tar.gz"
else
  echo "*** error @@@: ${backupDestination} or ${nextcloudData} is not available!"
  nextcloudMaintenanceSetMode off
  exit 1;
fi

echo "...okay"
echo ""

#########################################################
### 4. Backup installation directories and files and move to backupDestination
###

# set default size to zero for counting the 
# size of the nextcloud installation directory
sizeOfDir=0 

if [ -d "$backupDestination" ] && [ -d "$nextcloudInstallation" ]; then
  echo "Creating Backup of Installation Directory $nextcloudInstallation ..."
  sizeOfDir=$(du -sk "$nextcloudInstallation" | cut -f 1)
  tar -cpf - -C "$nextcloudInstallation" . \
    | pv --size "${sizeOfDir}"k -p --timer --rate --bytes \
    | gzip -c > "$backupDestination/$(DATESTAMP)_nextcloud-InstallationDir.tar.gz"
else
  echo "error@@@ ${backupDestination} or ${nextcloudInstallation} is not available!"
  nextcloudMaintenanceSetMode off
  exit 1
fi

echo "...okay"
echo ""

#########################################################
### 5. Deactivate Maintenance Mode
###

nextcloudMaintenanceSetMode off

#########################################################
### 6. Size, Location, Infomation Output
###

backupSize=$(du -csh "$backupDestination" | grep total | awk '{ print $1 }')
echo ""
echo "Done."
echo "Your Backup Information:"
echo "Location:      $backupDestination"
echo "Size:          $backupSize"
