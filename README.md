# Backup script for Raspberry Pi

Originally forked from https://github.com/aweijnitz/pi_backup

This script does an image backup of the Pi SD card using dd. It is not the most efficient method, but it creates a complete backup and it's easy to restore in case of complete card failure.

## Installation
- Clone this repo wherever you want with ```git clone https://github.com/fnando08/pi_backup.git```
- Make it executable. ```chmod +x backup.sh```
- Optionally you can update crontab to run it each some time.

__Usage__

Pi Backup Tool v1.0.0
Usage backup.sh OPTIONS [DEVICE] [OUTPUT_DIR]

Options:
    -h               Show this help
    -b COMMAND       Execute before backup (ex: stop some services)
    -a COMMAND       Execute after backup (ex: start some services)
    -l FILENAME      Log file
    -q               Don't show any output messages


___Example___

sudo ~/scripts/backup.sh -b"service apache2 stop" -a"service apache2 start" -c -l"/media/hdd/backups.log" /dev/mmcblk0 /media/hdd/backups

__Note__

If you select the compress option, it will take a long time due the Raspbeery Pi CPU.

/dev/mmcblk0 corresponds to the sdcard device on Raspberry Pi (executing raspbian), if you have installed your system on another device (like in my case, on a usb stick), execute "sudo fdisk -l".


