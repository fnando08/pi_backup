#!/bin/bash

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
	if [[ $QUIET == 0 ]]; then
		echo -ne "[$(date +%Y/%m/%d_%H:%M:%S)] $1";
	fi
	if [[ $LOG == 1 ]]; then
		echo -ne $1 >> "$LOG_DIR";
	fi
}

function println
{
	print "$1\n"
}

function SHOW_HELP {
			echo 'Pi Backup Tool v1.0.0';
			echo "Usage $(basename $0) OPTIONS [DEVICE] [OUTPUT_DIR]";
			echo "";
			echo "Options:";
			echo "    -h | --help                                   Show this help";
			echo "    -b | --before COMMAND         Execute before backup (ej: stop some services)"
			echo "    -a | --after COMMAND             Execute after backup (ej: start some services)"
			echo "    -l  | --log FILENAME                 Log the process on a file"
			echo "    -q | --quiet                                  Don't output any message"
}

EXECUTE_BEFORE=''
EXECUTE_AFTER=''
QUIET=0
LOG=0
COMPRESS=0

while getopts " hb:a:ql:d:c --help --before --after --quiet --log --compress" opt;  do
	case $opt in
		h)
			SHOW_HELP
			exit 0
		;;
		b)
			EXECUTE_BEFORE=$OPTARG
			println "The command \"$OPTARG\" will be executed before backup process"
			;;
		a)
		 EXECUTE_AFTER=$OPTARG
		 println "The command \"$OPTARG\" will be executed after backup process"
		 ;;
		q)
		 QUIET=1
		 ;;
		 c)
		 COMPRESS=1
		 ;;
		 l)
		 LOG=1
		 LOG_DIR=$OPTARG
		 ;;
		\?) 
			echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
			echo -e "Use ${BOLD}$SCRIPT -h${NORM} to see the help documentation."\\n
			exit 2
			;;
	esac
done

shift $(($OPTIND - 1))

DIR=$2
DEVICE=$1

if [ -z "$DIR" ]; then
	DIR=`pwd`
fi

if [ -z "$DEVICE" ]; then
	DEVICE='/dev/mmcblk0'
fi

# Check if backup directory exists
if [ ! -d "$DIR" ]; then
	println "Creating backup directory $DIR..."
	mkdir -p $DIR
fi

# Create a filename with datestamp for our current backup (without .img suffix)
OFILE="$DIR/backup_$(date +%Y%m%d%H%M%S).img"

println "Starting backup process of $DEVICE to $OFILE..."

# First sync disks
sync; sync

# Shut down some services before starting backup process
eval $EXECUTE_BEFORE

# Begin the backup process
println "This will take some time depending on your SD card size and read performance. Please wait..."
SDSIZE=`blockdev --getsize64 $DEVICE`;
pv -tpreb $DEVICE -s $SDSIZE | dd of=$OFILE bs=1M conv=sync,noerror iflag=fullblock

# Wait for DD to finish and catch result
RESULT=$?

eval $EXECUTE_AFTER

# If command has completed successfully, delete previous backups and exit
if [ $RESULT = 0 ]; then			
	if [ $COMPRESS = 1 ]; then
		println "Compressing..."
		tar zcf $OFILE.tar.gz $OFILE
		rm -rf $OFILE
	fi
	println "Backup was successfull!"
	exit 0
# Else remove attempted backup file
else
	println "Backup failed!." 
	println "Please check there is sufficient space on the HDD."
	exit 1	
fi


