#!/usr/local/bin/bash

#Automatic encrypted backup utility
#Exit codes:
#   0 - backup completed
#   1 - drive not connected
#   2 - error mounting drive
#   3 - error unmounting drive
#   9 - first run, ignored

export LC_ALL=en_US.UTF-8 #cron ignores the system setting and executes with C locale
CUR_DATE=$(date "+%Y-%m-%d")
BPATH=/opt/autobackup
LOGFL=$BPATH/backup-$CUR_DATE.log

get_archive_path () {
    if [ -z "$BACKPATH" ]; then
        echo /mnt/$MOUNTDIR/$CUR_DATE-$1
    else
        if [ ! -d /mnt/$MOUNTDIR/$BACKPATH ]; then
            mkdir /mnt/$MOUNTDIR/$BACKPATH
        fi
        echo /mnt/$MOUNTDIR/$BACKPATH/$CUR_DATE-$1
    fi
}

run_backup () {
    #The following assumes the paths adhere to a format: <path/to/back/up><whitespace><nameOfItem>
    #This format implies that no whitespace characters are allowed in paths to be backed up!
    item=$1
    name=$2
    arch=$(get_archive_path $name)".tar.gz.aes"
    echo "Adding $item and encrypting to archive $arch..." >> $LOGFL
    tar -cpzf - $item 2>>$LOGFL | openssl aes-256-cbc -salt -out $arch -pass file:$PASSFILE >> $BPATH/_ssl.log
    #tar logs directly into the main log file, but openssl to an intermetiade one so the logs don't mix up
    cat $BPATH/_ssl.log >> $LOGFL
    rm $BPATH/_ssl.log
    echo "Done." >> $LOGFL
}

recurse_directory () {
    #Store the path of requested directory, then all files within, then call itself for each subdir
    #This is resistant to whitespaces in filenames
    echo "$@" >> $BPATH/lines
    find "$@" -type f -maxdepth 1 | sort >> $BPATH/lines
    find "$@" -type d | tail -n +2 | sort | while read line; do
        recurse_directory "$line"
    done
}

run_listit () {
    #Format is the same as with run_backup
    item=$1
    name=$2
    arch=$(get_archive_path $name)".txt.tar.gz.aes"
    echo "Listing contents of $item..." >> $LOGFL
    #Recursively list files and subdirectories of a given item
    touch $BPATH/lines
    recurse_directory $item
    #Retrieve details of each item on the list and prettify with column
    #(awk is needed to temporarily replace the spaces in file names in ls output)
    cat $BPATH/lines | while read line; do
        ls -ld "$line"
    done | awk '{for(i=10;i<=NF;i+=1) {$9=$9"###"$i; $i=""}}1' | column -t | sed 's/###/ /g' > $BPATH/$name.txt
    #Archive and encrypt the list
    tar -cpvzf $BPATH/$name".tar.gz" $BPATH/$name".txt" 2>> $LOGFL
    openssl aes-256-cbc -salt -in $BPATH/$name".tar.gz" -out $arch -pass file:$PASSFILE >> $LOGFL
    #Clean up
    rm $BPATH/lines
    rm $BPATH/$name".tar.gz"
    rm $BPATH/$name".txt"
    echo "Done." >> $LOGFL
}

#Read the config
DISKNAME=$(sed -n 1p $BPATH/main.conf)   #serial number of the drive
MOUNTDIR=$(sed -n 2p $BPATH/main.conf)   #directory in /mnt to mount the drive
BACKPATH=$(sed -n 3p $BPATH/main.conf)   #path to store the backups (relative to mount point)
INFOMAIL=$(sed -n 4p $BPATH/main.conf)   #address to send notifications to
PASSFILE=$(sed -n 5p $BPATH/main.conf)   #path to file containing encryption password

#Check if the disk has been connected
#First check if this is the first run (and exit if so)
if [ ! -f $BPATH/dmesg.log ]; then
    dmesg > $BPATH/dmesg.log
    exit 9
fi
#Check the most recent dmesg output against the previously stored
dmesg > $BPATH/dmesg-new.log
DISKLINE=$(diff $BPATH/dmesg.log $BPATH/dmesg-new.log | grep "$DISKNAME" | tail -n 1)
#Store the most recent dmesg early, as a precaution against executing immediately again
mv $BPATH/dmesg-new.log $BPATH/dmesg.log
#Disk serial number can only occur on the attachment or deattachment lines. We are interested in
#the most recent state, i.e. the last line ("tail -n 1" above) - if it contains the word "detached"
#then the disk is no longer available (e.g. it could have been plugged in and immediately out
#between two consecutive executions of the script). Otherwise it is still there so we can proceed.
if [ -z "$DISKLINE" ] || [ -n "$(echo $DISKLINE | grep detached)" ]; then
    echo "Disk has not been connected"
    exit 1
fi

#At this point we are ready to perform the backup
echo "Starting backup at" $(date) > $LOGFL

#Extract the device name as the substring between "> " (always present -> cut) and ":" (on unknown position -> awk)
echo "Detected disk" $DISKNAME >> $LOGFL
DISK_DEV=$(echo $DISKLINE | cut -c 3-10 | awk -F ':' '{print $1}')
echo "Disk device id:" $DISK_DEV >> $LOGFL

#Assume that we mount the first partition of the disk
DISK_PRT=$(ls /dev | grep "$DISK_DEV" | sed -n 2p)
if [ ! -d "/mnt/$MOUNTDIR" ]; then
    mkdir /mnt/$MOUNTDIR
fi
mount "/dev/$DISK_PRT" "/mnt/$MOUNTDIR" 2>> $LOGFL
ERROR=$?
if [ $ERROR -gt 0 ]; then
    echo "Error $ERROR mounting disk /dev/$DISK_PRT!" >> $LOGFL
    echo "Error $ERROR mounting disk /dev/$DISK_PRT!" | mail -s "ERROR mounting disk!" $INFOMAIL
    exit 2
fi
echo "Disk /dev/$DISK_PRT mounted under /mnt/$MOUNTDIR" >> $LOGFL

#This is the right moment to send the first notification
echo "Disk $DISKNAME successfully mounted on" $(date) | mail -s "Disk connected, starting backup" $INFOMAIL

#Backup each location from the paths file
echo "Starting backing up locations from paths.conf" >> $LOGFL
cat $BPATH/paths.conf | while read -r line; do
    #Allow commenting out paths
    first=$(echo $line | cut -c 1)
    if [ "$first" != "#" ]; then
        run_backup $line #assumes line is whitespace-separated path and item name (NO SPACES IN PATHS ALLOWED!)
    fi
done

#Create file lists of stuff that does not get entirely backed up (essentially as above)
echo "Starting listing locations from lists.conf" >> $LOGFL
cat $BPATH/lists.conf | while read -r line; do
    first=$(echo $line | cut -c 1)
    if [ -n "$line" ] && [ "$first" != "#" ]; then
        run_listit $line
    fi
done

#Check remaining space and add it to the log
DISKSPCH=$(df -h | grep "$DISK_PRT" | awk '{print $4}')
DISKSPCB=$(df    | grep "$DISK_PRT" | awk '{print $4}')
echo "Space left on the disk: $DISKSPCH ($DISKSPCB bytes)" >> $LOGFL

#Unmount the drive and store the updated dmesg (wait a little bit to make sure it's updated)
umount /mnt/$MOUNTDIR 2>> $LOGFL
ERROR=$?
if [ $ERROR -gt 0 ]; then
    echo "Error $ERROR unmounting disk!" >> $LOGFL
    echo "Error $ERROR unmounting disk!" | mail -s "ERROR unmounting disk!" $INFOMAIL
    exit 3
fi
rmdir /mnt/$MOUNTDIR
sleep 5
dmesg > $BPATH/dmesg.log

#Notify about job completion
echo "Backup completed on" $(date) >> $LOGFL
cat $LOGFL | mail -s "Backup complete!" $INFOMAIL
