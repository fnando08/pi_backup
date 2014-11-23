#!/bin/bash
# 01 4    * * *   root    /home/pi/scripts/backup.sh

if [ "$(id -u)" != "0" ]; then
   echo "You must execute this script with root privileges" 1>&2
   exit 1
fi

#Check the shell
if [ -z "$BASH_VERSION" ]; then
    echo -e "Error: this script requires the BASH shell!"
    exit 1 
fi

type pv >/dev/null 2>&1 || { echo >&2 "Error: this scripts requires package 'pv' installed on the system"; exit 1; }


# First check if pv package is installed, if not, install it first
if `dpkg -s pv | grep -q Status;`
   then
      echo "Package 'pv' is installed." >> $DIR/backup.log
   else
      echo "Package 'pv' is NOT installed." >> $DIR/backup.log
      echo "Installing package 'pv'. Please wait..." >> $DIR/backup.log
      apt-get -y install pv
fi

function print 
{
   echo $QUIET;
    if [[ $QUIET == 0 ]]; then
            echo -ne "$(date +%Y/%m/%d_%H:%M:%S) $1";
    fi

    if [[ $LOG == 1 ]]; then
            echo -ne $1 >> "$LOG_DIR";
    fi
}

function SHOW_HELP {
	echo 'Pi Backup Tool v1.0.0';
	echo "Usage `pwd` PARAMETERS";
	echo "";
	echo "Options:";
	echo "    -h | --help		Show this help";
	echo "    -o | --output-dir	Output directory";
	echo "    -b | --before		Execute before backup (ej: stop some services)"
	echo "    -a | --after		Execute after backup (ej: start some services)"
       echo "    -l | --log    Log the process"
}

DIR=`pwd`
EXECUTE_BEFORE=''
EXECUTE_AFTER=''
QUIET=0
LOG=0

while getopts " ho:b:a:q --help --output-dir --before --after --quiet" opt;  do
  case $opt in
    h)
	SHOW_HELP
	exit 0
	;;
    o)
      DIR=$OPTARG
      echo "Selected output dir $DIR"
      ;;
    b)
      EXECUTE_BEFORE=$OPTARG
      echo "The command \"$OPTARG\" will be executed before backup process"
      ;;
    a)
     EXECUTE_AFTER=$OPTARG
     echo "The command \"$OPTARG\" will be executed after backup process"
     ;;
    q)
     QUIET=1
     ;;
     l)
     LOG=1
     ;;
    \?) 
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      #If you just want to display a simple error message instead of the full
      #help, remove the 2 lines above and uncomment the 2 lines below.
      #echo -e "Use ${BOLD}$SCRIPT -h${NORM} to see the help documentation."\\n
      #exit 2
      ;;
  esac
done

if [ 1 == LOG ]; then
  LOG_DIR="$DIR/backup.log";
fi

# Check if backup directory exists
if [ ! -d "$DIR" ];
   then
      print "Creating backup directory $DIR..."
      mkdir -p $DIR
fi

print "Starting backup process!"

exit 1;
# Create a filename with datestamp for our current backup (without .img suffix)
OFILE="$DIR/backup_$(date +%Y%m%d_%H%M%S)"

# Create final filename, with suffix
OFILEFINAL=$OFILE.img

# First sync disks
sync; sync

# Shut down some services before starting backup process
"`EXECUTE_BEFORE`"


# Begin the backup process, should take about 1 hour from 8Gb SD card to HDD
echo "Backing up SD card to USB HDD." >> $DIR/backup.log
echo "This will take some time depending on your SD card size and read performance. Please wait..." >> $DIR/backup.log
SDSIZE=`blockdev --getsize64 /dev/mmcblk0`;
pv -tpreb /dev/mmcblk0 -s $SDSIZE | dd of=$OFILE bs=1M conv=sync,noerror iflag=fullblock

# Wait for DD to finish and catch result
RESULT=$?

# Start services again that where shutdown before backup process
echo "Start the stopped services again." >> $DIR/backup.log
service cron start
service couchdb start
nginx

# If command has completed successfully, delete previous backups and exit
if [ $RESULT = 0 ];
   then
      echo "Successful backup, previous backup files will be deleted." >> $DIR/backup.log
      rm -f $DIR/backup_*.img
      mv $OFILE $OFILEFINAL
      # echo "Backup is being tarred. Please wait..." >> $DIR/backup.log
      # tar zcf $OFILEFINAL.tar.gz $OFILEFINAL
      # rm -rf $OFILEFINAL
      echo "RaspberryPI backup process completed! FILE: $OFILEFINAL" >> $DIR/backup.log
      echo "____ BACKUP SCRIPT FINISHED $(date +%Y/%m/%d_%H:%M:%S)" >> $DIR/backup.log
      exit 0
# Else remove attempted backup file
   else
      echo "Backup failed! Previous backup files untouched." >> $DIR/backup.log
      echo "Please check there is sufficient space on the HDD." >> $DIR/backup.log
      rm -f $OFILE
      echo "RaspberryPI backup process failed!" >> $DIR/backup.log
      echo "____ BACKUP SCRIPT FINISHED $(date +%Y/%m/%d_%H:%M:%S)" >> $DIR/backup.log
      exit 1
fi


