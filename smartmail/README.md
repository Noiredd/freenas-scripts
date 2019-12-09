### SMARTmail

This is a simple script that will collect results of SMART health checks (using `smartctl`) and send them as (formatted) emails to a given address (with just `mail`).

#### Guide

1. Download the scripts (`mail.sh` and `format.py`) to a directory of your choice. In my case it's `/opt/smartmail` - remember that path.
Make sure to `chmod` execution privileges to `mail.sh`.
2. Configure the main script: set `HERE` variable to the aforementioned path (necessary in step 4), set `MAIL` to the address you wish to receive the reports on.
3. Select devices which you want to query: create a file `disks.txt` (obviously, in the same directory) and list devices in it, line by line.
Do not use complete drive paths (i.e. don't include "/dev/")! State only the names of devices (e.g. `ada0`), one entry per line.  
(At this point you may want to test the script.)
4. Log in to your FreeNAS web interface and add a cron job with this script (Tasks -> Cron Jobs). Mine runs every 1st day of the month, after the long SMART self-test.

Voila, enjoy regular updates on the health status of your HDDs!
