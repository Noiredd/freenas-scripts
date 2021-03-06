### OpenVPN + Transmission

This is a set of scripts to manage a Transmission plugin jail with an OpenVPN tunnel - specifically with [privateinternetaccess.com (PIA)](https://privateinternetaccess.com/).

The primary obstacle this aims to solve is the port forwarding request.
PIA by default does not give you any open port on their side.
This means that Transmission will not work well - particularly, you will be unable to seed.
You must explicitly make a request to PIA to assign you a port,
and inform Transmission of the port number to listen on.
Of course, in case of a connection reset or jail/server restart, this needs to be automated.

This guide will let you accomplish the following:
* configure OpenVPN to connect to PIA,
* get the port forwarding working,
* make sure **all** Transmission traffic goes through VPN and nowhere else,
* make sure that whenever the connection goes down, it will automatically restart.

The guide will **not** explain how to:
* set up Transmission (read about it in the [guide](http://doc.freenas.org/11/plugins.html#installing-plugins)),
* attach the storage (read about it in the [guide](http://doc.freenas.org/11/jails.html#add-storage)).

#### Guide

1. Get Transmission running using the GUI, set up storage et cetera.
I recommend setting a username and password for the remote client.
2. SSH into the jail.
```bash
# list all available jails, check the index of the transmission jail
jls
# let's assume the jail ID was 4
jexec 4 tcsh
```
3. Set up OpenVPN.  
The following guide is adapted from [Tango](https://forums.freenas.org/index.php?members/tango.44547/)'s [great guide](https://forums.freenas.org/index.php?threads/guide-setting-up-transmission-with-openvpn-and-pia.24566/), which has in turn been adapted from [fizassist](https://forums.freenas.org/index.php?members/fizassist.77752/)'s [earlier guide](https://forums.freenas.org/index.php?threads/guide-setting-up-transmission-with-openvpn-and-pia.24566/page-24#post-404858), and has bits of [shutyourj](https://www.reddit.com/user/shutyourj)'s [reddit tutorial](https://www.reddit.com/r/freenas/comments/41fhz3/configuration_guide_for_openvpn_and_ipfw_so_that/) in it.
I highly recommend putting everything in `/usr/local/etc/` as this is OpenVPN's default settings location.  
See the [list of PIA servers that allow port forwarding](https://www.privateinternetaccess.com/helpdesk/kb/articles/how-do-i-enable-port-forwarding-on-my-vpn).
```bash
cd /usr/local/etc
mkdir openvpn
cd openvpn
# you will need the following packages:
pkg update
pkg install jq
pkg install wget
pkg install openvpn
# download and unpack the PIA configuration files
wget https://www.privateinternetaccess.com/openvpn/openvpn.zip --no-check-certificate
unzip -d pia openvpn.zip
cp pia/ca.rsa.2048.crt .
cp pia/crl.rsa.2048.pem .
# pick a server to connect to (needs to support port forwarding - see list above)
cp pia/Romania.ovpn openvpn.conf
# put your PIA username/password in a file (example: x0000000/password)
cat > pia.credentials <<X
x0000000
password
X
sed -i '' 's/auth-user-pass/auth-user-pass pia.credentials/' openvpn.conf
# make OpenVPN launch at boot time
cat > /etc/rc.conf.d/openvpn <<X
openvpn_enable="YES"
openvpn_configfile="/usr/local/etc/openvpn/openvpn.conf"
X
```
4. Set up the scripts that automate port forwarding and downtime detection.
I like to put them in a separate directory, for example `/opt/openvpn/`.
Feel free to adjust that to your liking,
but keep in mind that each script actually uses the absolute path to the others,
so you will have to `sed` them all in this case (change the `$path` variable).
```bash
# get the scripts (read the comments in them for details)
wget https://raw.githubusercontent.com/Noiredd/freenas-scripts/master/openvpn/vpn_isrunning.sh
wget https://raw.githubusercontent.com/Noiredd/freenas-scripts/master/openvpn/vpn_log.sh
wget https://raw.githubusercontent.com/Noiredd/freenas-scripts/master/openvpn/vpn_monitor.sh
wget https://raw.githubusercontent.com/Noiredd/freenas-scripts/master/openvpn/vpn_request.sh
wget https://raw.githubusercontent.com/Noiredd/freenas-scripts/master/openvpn/vpn_up.sh
# set the execution privilege bit
chmod +x vpn_*
# configure openvpn to execute the script at start time
cat >> /usr/local/etc/openvpn/openvpn.conf <<X
up /opt/openvpn/vpn_up.sh
up-restart
X
# if you set your credentials for Transmission RPC, write them to a file
cat > transmission.credentials <<X
username
password
X
# in case the port number acquisition fails, the script can notify about that
# by writing to a given file - just store its path under notify.path
# (this is recommended, as the downtime detector will also write there)
printf '/media/downloads/VPN.log' > notify.path  # adjust the path
# finally, set cron to run the monitoring script periodically and as root
# (adjust the path if necessary)
echo "* * * * * /opt/openvpn/vpn_monitor.sh" > cron.tab
crontab cron.tab
```
At this moment the OpenVPN downtime detector is up and running.
You can temporarily stop it by creating a file `stop.it`,
whose presence will cease all activity of the scripts
(i.e. cron monitoring - **not** the OpenVPN service).
5. Configure IPFW so none of the Transmission traffic is allowed outside VPN.
```bash
# download the reference rules
# (alternatively, you could download the entire repository and unzip files)
wget https://raw.githubusercontent.com/Noiredd/freenas-scripts/master/openvpn/ipfw.rules
# my reference rules are for a gateway 192.168.0.0, so be sure to adjust for yours
# the actual configuration happens now
cat > /etc/rc.conf.d/ipfw <<X
firewall_enable="YES"
firewall_script="/opt/openvpn/ipfw.rules"
X
```
6. Exit the jail and restart it.
You can check that it works using [TorGuard's tool for torrent IP checking](torguard.net/checkmytorrentipaddress.php).

#### Caveats
The reason a separate monitoring script ran by cron is needed is due to some problems I have had with putting everything in a single up script.
When the entire script was called by openvpn, I could never set the port using `transmission-remote`.
Simply nothing would happen, no error message even.
After digging some more (read on [SO](https://unix.stackexchange.com/q/447421/293652) if you're curious), I found that `transmission-remote` would segfault when it was called by openvpn's up script - even though I could run the commands myself from bash.  
As a workaround, I use the fact that cron can execute tasks as root.
Up script obtains the port and stores it in a file,
and a periodic cron job reads it and sets the port on `transmission-remote`, then deletes it.

In the long run it's not such a bad thing, because the periodic task is necessary anyway: to scan for VPN downtimes and restart the service.
