### AutoBackup

This script automates backups of specified folders onto an external drive.
The idea is that you plug such a disk in *only* to perform a backup and plug it out,
perhaps storing it at a different location.
I used it with my eSATA (yes, yes, USB is unreliable, etc) disk as a measure against catastrophies -
to make sure my most important data stays safe in more than 2 locations.  
One of the assumptions I've made is that these backups should be readable on Windows machines,
so the script does not use ZFS replication - instead it `tar`s the data and encrypts the archives with `openssl`.

Since I wanted it to be as automatic as possible, the program will do the following:
* detect whether your specific device has been plugged in and mount it,
* create compressed archives of the folders you specify and encrypt them (password is read from a file),
* create comprehensive lists of content of the folders you specify and encrypt them,
* mail you when it starts working and when it's done (or notify about any problems).

Limitations:
* there can be no whitespace characters in the paths you want to back up or list (but if the contents have whitespaces in their names it should be okay),
* the disk you connect is expected to only have a single partition (this can be hacked though),
* it has to run from the true root (i.e. not from a jail).

Requirements:
* no additional packages (tested on FreeNAS 11.1 but should work on any other as it only uses the basic tools).

This guide covers setting up and configuring it.
I highly recommend reading the script first and doing a dry run.
This has to be run from above the jails so I will assume that you know what you're doing.
I'm running this weekly on my own NAS and everything is fine but of course [no guarantees](../LICENSE.md) are given.

#### Configuration guide

1. First you need to know how to identify your disk.
The script works by scanning `dmesg` for the specific string containing the name or serial number of your disk.
To obtain it, SSH into your jail, plug the disk in and check the output of the following:
```bash
dmesg | tail
```
You should see something similar to this:
```
ada6 at ahcich0 bus 0 scbus0 target 0 lun 0
ada6: <WDC WD10EARS-00MVWB0 51.0AB51> ATA8-ACS SATA 2.x device
ada6: Serial Number WD-xxxxxxxxxxxx
ada6: 300.000MB/s transfers (SATA 2.x, UDMA6, PIO 8192bytes)
ada6: Command Queueing enabled
ada6: 953869MB (1953525168 512 byte sectors)
ada6: quirks=0x1<4K>
```
When you disconnect the drive, the output will contain something like that:
```
ada6 at ahcich0 bus 0 scbus0 target 0 lun 0
ada6: <WDC WD10EARS-00MVWB0 51.0AB51> s/n WD-xxxxxxxxxxxx detached
(ada6:ahcich0:0:0:0): Periph destroyed
```
I recommend using the disk serial number as the identifying string.
Store it somewhere, it will be needed in step 3.

2. Get the script.
I recommend creating some new folder for the script and its configs, its temporary files etc.
I created a folder `/opt/autobackup` and `cd`'s into it - so the rest of the guide assumes that `pwd` is that path.  
Download the script:
```bash
wget https://raw.githubusercontent.com/Noiredd/freenas-scripts/master/autobackup/backup.sh
chmod +x backup.sh
# It turns out that somewhere between git and GitHub, '\n' endlines were changed to '\r\n'
# the following sed will get it back to unixy.
sed 's/\r\n/\n/g' <backup.sh >backup.sh
```
**Important:** if you decided on a different path, you have to edit the script accordingly:
variable `BPATH` (line 10) tells the script where to look for configs, put any temps and so on.

3. Configuration - main part.  
The script expects a file `main.conf` in its directory.
It shall contain 5 lines (and nothing else, no whitespace, no comments etc):
    * identifying string of the disk - mentioned in step 1,
    * directory under which the disk will be mounted in `/mnt` - I leave it for the user to decide, to be sure there are no collisions
    (the path is relative to `/mnt`, so a value of `backup` will resolve to `/mnt/backup`),
    * path to put the backups, relative to the above path - in case you had other stuff on your disk and wanted to put the backups in the specific folder on it; can be left empty if you want the archives directly on the disk root
    (following the above example, `backups` will resolve to `/mnt/backup/backups`),
    * mail address to notify about progress,
    * path to a file containing the password to encrypt the backups (this line might have to be `\n`-terminated).

Example config file:
```
WD-xxxxxxxxxxxx
wd1tb
backup
my_address@mail.net
/opt/autobackup/password.txt
```
Which will mount the drive `WD-xxxxxxxxxxxx` under `/mnt/wd1tb` and put backups in `/mnt/wd1tb/backup`,
encrypting them with the password found in `/opt/autobackup/password.txt`.

4. Configuration - paths.  
In this step, you describe which folders you want backed up. As mentioned, there are two modes of operation here, and two configuration files that follow.  
In the file `paths.conf` you are supposed to put paths of all the folders you want entirely archived, compressed and encrypted.
Those will be fully backed up on your disk.
The format of the file is as follows:  
`/path/to/folder/being/backed-up archive-name`
This means all contents of `/path/to/folder/being/backed-up` will be archived in the file
(following the example mount point from before) `/mnt/wd1tb/backup/yyyy-mm-dd-archive-name.tar.gz.aes` (substitute the current date for `yyyy-mm-dd`).
Note how there is exactly a single whitespace allowed in the path - it separates the path from archive name.
As a consequence, **locations with spaces in their paths cannot be backed up**.
This is however only a limitation of the config file parsing, so 1) it's not a problem if somewhere in `/path/to/folder/being/backed-up` there exists a `file with space.txt`, and 2) it might get eventually fixed (PRs welcome!).  
**Note**: each path in the file has to be followed by `\n`!  
Second mode of operation is listing files.
While a comprehensive backup is the only way to go with the most crucial files,
for stuff like music collection I don't really need to store it all to the byte (the backup disk is only so big) -
it's enough for me to know *what was in there*.
This is exactly what `lists.conf` is for.
Its format is like above, but the contents of each location will only be *listed* into a file.
Each path will be scanned breadth-first, and printed files-first, alphabetically sorted, formatted like `ls -l`.
The resulting txt file will be archived, compressed and encrypted as above, and stored as `/mnt/wd1tb/backup/yyyy-mm-dd-archive-name.txt.tar.gz.aes`.
Note the `.txt` in the filename - this is to distinguish the file list archive from a complete backup, if you choose to do both for some location.

5. With the three configuration files in place, all there's left to do is to set up a `cron` job to execute the script periodically.
Log in to your FreeNAS GUI, navigate to *Tasks*, then *Cron Jobs* and add a job.
I *think* you have to be `root` to mount any disks so enter `root` as the *user*, then path to the script under *command* (in the example case: `/opt/autobackup/backup.sh`).
I strongly recommend setting the schedule to every minute, every hour, every day - the whole point is to have this running all the time,
so that when you decide to connect the disk it is noticed immediately.
Execution of the script (if the disk hasn't been plugged in, so 99.9% of the time) ends right after calling `dmesg` followed by `diff` and `grep` so its CPU impact should be unnoticeable.

#### Usage guide
With all this set up, the normal operation is very simple: the disk is not connected and nothing happens.  
When you eventually decide to connect and power on your device, the following is done:
* new device is detected and an email is sent notifying that the script is working,
* the first partition of the disk is mounted
(should this fail, an error message will be sent and the script will immediately exit),
* all locations from `paths.conf` are `tar`ed (with `-p` and `-z`) and encrypted (using `openssl`, AES-256-CBC with salt),
* all locations from `lists.conf` are listed, `tar`ed and encrypted (as above),
* the disk is unmounted and its mount point removed (failure to unmount will be emailed),
* an email is sent notifying you that you can safely power off and disconnect your disk.

If your disk is powered on during the first run of the script, it will not detect it.
So make sure the device is disconnected before you start the cron job.

PS: this script is not secured against power loss during backup.
I recommend plugging your external HDD into the same UPS your box is in
(if you have an HDD enclosure which needs power)
in hope that a minor outage will not interrupt the operation.
But in the case of a major outage (i.e. the server shuts down)
the script will probably be interrupted halfway and you will have to clean up manually.

#### Accessing your backups on Windows
Since my main machine is running Windows, I made some choices in the design so that the (encrypted) backups can be read from Windows.

1. Partitions  
Your disk should be formatted as UFS - I know of no other file system that is both writable from FreeNAS (this eliminates NTFS) and readable from Windows (this eliminates ZFS).
I've followed [Randall Wood's guide](http://therandymon.com/index.php?/archives/285-Backing-Up-FreeNAS-to-an-external-hard-drive.html) to do that.  
After plugging in your disk, figure out its device id (either by reading `dmesg` or by manually checking `ls /dev`).
In my case it was `ada6`.
```bash
# Start by removing the existing filesystem
dd if=/dev/zero of=/dev/ada6 bs=1m count=128
fdisk -BI /dev/ada6      # Format the external drive: one huge partition, bootable
# I recommend 'ls /dev' again to see the name assigned to the new partition - in my case it was ada6a
bsdlabel -wB /dev/ada6a  # Write standard (bootable) disk label to the 1st partition
newfs -O2 -U /dev/ada6a  # Format the partition with UFS2 and soft updates
```
I deliberately skipped the `gpt` step as I don't think FreeNAS 11.1 ships it (at least it returned `Command not found` for me),
replacing it with `dd` as suggested by [Dan in his guide](https://www.dan.me.uk/blog/2009/06/03/partitioningformatting-disks-in-freebsd-manual-method/).  
By the way, do I have to remind that this is **super** dangerous if you're not careful?

2. Mounting UFS on Windows  
...is not possible.
But you can use something like [`ufs2tools`](http://ufs2tools.sourceforge.net) to manually access the contents of a UFS partition.
The steps are roughly as follows:
 * navigate to *Control Panel*, then *Computer Management* (under *Administrative Tools*), then *Disk Management*,
 * find the number of your disk and the index of the "slice" your data is in (starting at 1, not 0),
 * use `bsdlabel` to figure out the index of the partition (`a` translated to 0, `b` to 1 etc. - yes this is 0-indexed for a change),
 * use `ufs2tool` to list (`-l`) or extract (`-g`) data from the disk.

This guide didn't exactly work for me, maybe because my disk only has a single partition.
Even though, according to their numbering scheme, my *slice* would be called `2/1`, when I did `bsdlabel 2/1` I'd get a "could not open device" error.
Calling `bsdlabel 2` did the trick.  
Then you're supposed to do `ufs2tool d/s/p -l` to list the data(`d` for disk, `s` for slice, `p` for partition),
but when I did `ufs2tool 2/1/0 -l` I'd again get the "could not open device".
Strangely enough, `ufs2tool 2/0/ -l` worked - with this hanging slash.  
To copy files from the UFS partition onto your internal HDD, you run `ufs2tool d/s/p -g /path/to/the/archive.tar.gz.aes C:\save\this\here\archive.tar.gz.aes`, in my case `ufs2tool 2/0/ -g ...`.

3. Decrypt data on Windows  
The script, unless you change something, encrypts the archive with OpenSSL's implementation of AES-256-CBC.
In order to decrypt those files, I recommend getting an OpenSSL binary - for example from [overbyte.eu](http://wiki.overbyte.eu/wiki/index.php/ICS_Download#Download_OpenSSL_Binaries_.28required_for_SSL-enabled_components.29).
I've tried other AES-capable software but this probably has to do with OpenSSL's output file format.
I also recommend checking which version does your FreeNAS box use (`openssl version`) and getting the matching binary for Windows.  
To decrypt an archive:  
`openssl aes-256-cbc -d -salt -in C:\path\to\archive.tar.gz.aes -out C:\path\to\unencrypted.tar.gz`  
it will prompt you for a password, or you could also pass something like `-pass file:C:\my\password.txt` (untested).
