#!/bin/bash

# nextcloud backup script
# github.com/3vincent/nextcloud-backup

### SETUP AREA
###
databasePassword='' #set default
encryptionPassword='' #set default

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
#    2. Backup Database
#    3. Backup Data Dir
#    4. Backup Installation Dir in Apache Web Folder
#    5. Deactivate Maintenance Mode
#    6. Size, Location and Info-Output
#
#    Script does not check for available free space on the drive!
#    Have Fun
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

echo "############## Nextcloud Backup 101 ##############"
echo ""

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
  sudo -u "${apacheUser}" php "${nextcloudInstallation}"/occ maintenance:mode --"${modeSet}"

  # if previous command ended without error
  if [ "$?" -ne "0" ]; then
    echo "*** Error: Setting maintenance mode to ${modeSet} failed"
    echo "*** exiting..."
    exit 1;
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

preparations() {
  #########################################################
  ### 0. Preparations
  ###

  ## Check if root
  if [ "$EUID" -ne 0 ]; then
    echo "*** error *** Please run as root"
    exit 1;
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
    "$backupDestination"
    "$nextcloudInstallation"
    "$nextcloudData"
    "$TMP_PATH"
  )

  for usersetpath in "${USERDIRPATHS[@]}"; do
    if [ ! -d "$usersetpath" ]; then
      echo "***error *** $usersetpath does not exist on this system. Please check your setting in the configfile: $CONFIGFILE"
      echo "exiting..."
      exit 1;
    fi
  done

  # check if database type is either mysql or postgres
  if [ "$databaseType" != "mysql" ] && [ "$databaseType" != "postgres" ]; then
    echo "no database type set"
    echo "=> Please set a databaseType of either mysql or postgres in the config file"
    echo "exiting..."
    exit 1;
  fi

  # check if the environment variable for the __database password__ is set
  # if not use the password that was set in the config file
  # env var password is always preferred to the one set inside the file
  if [ -z "$NEXTCLOUDDATABASEPW" ] && [ -z "$databasePassword" ]; then
    echo "no database password set"
    echo "exiting..."
    exit 1;
  fi

  if [ -n "$NEXTCLOUDDATABASEPW" ]; then
    databasePassword=$NEXTCLOUDDATABASEPW
  fi

  if [ -z "$NEXTCLOUDDATABASEPW" ] && [ -n "$databasePassword" ]; then
    echo "Using database password that was set in the config file"
  fi

  # check if encryption is set to true or false
  if [ -z "${encryption}" ]; then
    echo "*** Error: encryption mode needs to be either true or false"
    echo "exiting..."
    exit 1;
  fi

  if [ "$encryption" -ne 1 ] && [ "$encryption" -ne 0 ]; then
    echo "*** Error: encryption mode needs to be either true or false"
    echo "exiting..."
    exit 1;
  fi    

  # check if the environment variable for the __file encryption password__ is set
  # if not use the password that was set in the config file
  # env var password is always preferred to the one set inside the file
  if [ -z "$NCFILEENCRYPTIONPW" ] && [ -z "$encryptionPassword" ]; then
    echo "no encryption password set"
    echo "exiting..."
    exit 1;
  fi

  if [ -n "$NCFILEENCRYPTIONPW" ]; then
    encryptionPassword=$NCFILEENCRYPTIONPW
  fi

  if [ -z "$NCFILEENCRYPTIONPW" ] && [ -n "$encryptionPassword" ]; then
    echo "Using encryption password that was set in the config file"
    echo ""
  fi

  ## check if cli tool exist on the system
  declare -a CLI_TOOLS

  CLI_TOOLS=(
    "pv"
    "tar"
    "gzip"
    "du"
    "php"
  )

  for tool in "${CLI_TOOLS[@]}"; do
    if [ ! "$(which "$tool")" ]; then
      echo "***error *** $tool does not exist on this system. Please install it! Exiting..."
      exit 1;
    fi
  done

  if [ "$databaseType" = 'mysql' ]; then
    if [ ! "$(which mysqldump)" ]; then
      echo "***error *** mysqldump does not exist on this system. Please install it! Exiting..."
      exit 1;
    fi
  fi

  if [ "$databaseType" = 'postgres' ]; then
    if [ ! "$(which pg_dump)" ]; then
      echo "***error *** pg_dump does not exist on this system. Please install it! Exiting..."
      exit 1;
    fi
  fi

  # fetch current date as YYYYMMDDHHMMSs
  DATESTAMP() { date +%Y-%m-%d_%H-%M-%S; }

  # Create Backup Directory TARGET
  archiveDirectoryName="nextcloud_backup_$(DATESTAMP)"
  backupDestination="${backupDestination%/}/$archiveDirectoryName"

  if [ -d "$backupDestination" ]; then
    echo "*** error*** Directory: $backupDestination already exists!"
    exit 1;
  fi

  mkdir "$backupDestination"

  # check if backup destination exists after creation
  if [ ! -d "$backupDestination" ]; then
    echo "***error *** Directory does not exist: $backupDestination"
    exit 1;
  fi

  # check if installation directory is valid in SETUP VAR
  if [ ! -d "$nextcloudInstallation" ]; then
    echo "***error *** Directory not found: $nextcloudInstallation"
    exit 1;
  fi

  # check if data directory is valid in SETUP VAR
  if [ ! -d "$nextcloudData" ]; then
    echo "***error *** Directory not found: $nextcloudData"
    exit 1;
  fi
}

databaseBackup() {
  #########################################################
  ### DATABASE Backup
  ###
  thisDatabaseType="${1}"
  FIXEDDATESTAMP=$(DATESTAMP)

  if [ "$thisDatabaseType" != "mysql" ] && [ "$thisDatabaseType" != "postgres" ]; then
    echo "*** Error: DatabaseType has to be either mysql or postgres"
    echo "exiting..."
    exit 1;
  fi

  echo ""
  echo "Creating backup of ${databaseType} database ${databaseDatabaseName} ..."

  if [ "$thisDatabaseType" = "mysql" ]; then
    databaseBackupMysql
  fi

  if [ "$thisDatabaseType" = "postgres" ]; then
    databaseBackupPostgres
  fi

  echo "...done"
  echo ""
}

databaseBackupMysql() {
  ## MYSQL BACKUP
  # check if mysql4byte SETUP VAR is set to true or false
  if [ $mysql4byte -ne 1 ] && [ $mysql4byte -ne 0 ]; then
    echo "*** Error: $mysql4byte has to be either true or false"
    exit 1;
  fi

  # write mysql config file that is used to hide the password from the process list
  mysqlConfigFile=${TMP_PATH}/.mylogin.cnf
  printf "[mysqldump]\nuser=%s\npassword=%s\n" "${databaseUser}" "${databasePassword}" > $mysqlConfigFile
  chmod 600 ${mysqlConfigFile}

  # prepare backup
  if [ $mysql4byte -eq 1 ]; then
    mysqldump --defaults-file=${mysqlConfigFile} \
    --default-character-set=utf8mb4 \
    --single-transaction \
    -h localhost "$databaseDatabaseName" \
    | gzip -9c > "$backupDestination/${FIXEDDATESTAMP}_nextcloud_mysqlDatabase.sql.gz"
  fi

  if [ $mysql4byte -eq 0 ]; then
    mysqldump --defaults-file=${mysqlConfigFile} \
    --single-transaction \
    -h localhost "$databaseDatabaseName" \
    | gzip -9c  > "$backupDestination/${FIXEDDATESTAMP}_nextcloud_mysqlDatabase.sql.gz"
  fi

  rm ${mysqlConfigFile}
}

databaseBackupPostgres() {
  ## POSTGRES BACKUP
  PGPASSWORD="$databasePassword" pg_dump "$databaseDatabaseName" -h 127.0.0.1 \
    -U "$databaseUser" \
    | gzip -9c > "$backupDestination/${FIXEDDATESTAMP}_nextcloud_postgresDatabase.sql.gz"
}

dataBackup() {
  #########################################################
  ### Backup Data Directory
  ###

  if [ -d "$backupDestination" ] && [ -d "$nextcloudData" ]; then
    echo "Creating backup of data directory $nextcloudData ..."
    sizeOfDir=$(du -sk "$nextcloudData" | cut -f 1)
    tar -cpf - -C "$nextcloudData" . \
      | pv --size "${sizeOfDir}"k -p --timer --rate --bytes \
      | gzip -c > "$backupDestination/$(DATESTAMP)_nextcloud-DataDir.tar.gz"
  else
    echo "*** error @@@: ${backupDestination} or ${nextcloudData} is not available!"
    nextcloudMaintenanceSetMode off
    exit 1;
  fi

  echo "...done"
  echo ""
}

installdirBackup() {
  #########################################################
  ### Backup installation directories and files
  ### and move to backupDestination
  
  # set default size to zero for counting the 
  # size of the nextcloud installation directory
  sizeOfDir=0 

  if [ -d "$backupDestination" ] && [ -d "$nextcloudInstallation" ]; then
    echo "Creating backup of installation directory $nextcloudInstallation ..."
    sizeOfDir=$(du -sk "$nextcloudInstallation" | cut -f 1)
    tar -cpf - -C "$nextcloudInstallation" . \
      | pv --size "${sizeOfDir}"k -p --timer --rate --bytes \
      | gzip -c > "$backupDestination/$(DATESTAMP)_nextcloud-InstallationDir.tar.gz"
  else
    echo "error@@@ ${backupDestination} or ${nextcloudInstallation} is not available!"
    nextcloudMaintenanceSetMode off
    exit 1;
  fi

  echo "...done"
  echo ""
}

encryptFiles() {
  #########################################################
  ### Encrypt all archive file with GnuPG
  ### 
  echo ""
  echo "Encrypting all files with GnuPG..."

  for file in ${backupDestination%/}/* 
  do
    echo "${encryptionPassword}" | gpg \
    --output ${file}.gpg \
    --symmetric \
    --cipher-algo AES256 \
    --pinentry-mode loopback \
    --passphrase-fd 0 \
    ${file}

    # if previous command ended without error remove the file
    if [ "$?" -eq "0" ]; then
      rm ${file}
    else
      echo "*** Error: Encryption failed"
      echo "*** exiting..."
      exit 1;
    fi
  done

  echo "...done"
  echo ""
}

checkIfEncryption() {
  if [ "$encryption" -eq 1 ]; then
    encryptFiles
  fi
}

finishOutput() {
  #########################################################
  ### Output Information: Size, Location, Infomation Output
  ###
  backupSize=$(du -csh "$backupDestination" | grep total | awk '{ print $1 }')

  echo ""
  echo "Done."
  echo "Your backup information:"
  echo "Location:      $backupDestination"
  echo "Size:          $backupSize"
  echo ""
}

main() {
  #########################################################
  ### Main Function
  ###

  preparations

  nextcloudMaintenanceSetMode on

  databaseBackup "$databaseType"

  dataBackup

  installdirBackup

  nextcloudMaintenanceSetMode off

  checkIfEncryption

  finishOutput
}

main
