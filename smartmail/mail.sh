#!/usr/local/bin/bash
HERE=/opt/smartmail
MAIL=""
for disk in $(cat $HERE/disks.txt)
do
	smartctl -a /dev/$disk | python $HERE/format.py | mail -s "$(echo -e "SMART results for disk $disk\nContent-Type: text/html")" $MAIL
	sleep 3
done
