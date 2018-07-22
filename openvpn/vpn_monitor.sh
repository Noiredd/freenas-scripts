#!/usr/local/bin/bash
# This does two things:
# 1. checks if a port has been obtained and assigns it to transmission,
# 2. checks whether the connection is up and restarts otherwise.
# This has to be ran as a cron job as a workaround for some segfaults due to
# mismatched libraries which popped up for me when executing this directly from
# the openvpn up script.
path="/usr/local/etc/openvpn"
cred="$path/transmission.credentials"
intf="tun0"

# Set Transmission port
if [ -f $path/port.id ]; then
  port=$(cat $path/port.id)
  rm $path/port.id
  if [ -f $cred ]; then
    user=$(sed -n 1p $cred)
    pass=$(sed -n 2p $cred)
    transmission-remote -n $user:$pass -p $port
  else
    transmission-remote -p $port
  fi
  . $path/vpn_log.sh "Setting Transmission port to $port"
fi

# Check if the connection is up
# The following line queries ifconfig for the specific interface name,
# redirecting stderr to stdout - this is necessary, because although ifconfig
# outputs normal printouts to stdout, when it fails to find the interface
# (which is the event we want to capture) it decides to write to stderr for
# whatever reason.
# Then we feed whatever we got to awk which goes through it line by line, and
# when it encounters the string "does not exist" (which is either not going to
# happen at all, or right on the first line), it outputs 1 (otherwise 0).
check=$(ifconfig $intf 2>&1 | awk '/does not exist/ {f=1}; BEGIN{f=0}; END{print f}')
# If we got 1, means the tunnel should be (re?)started.
if [ "$check" == "1" ]; then
  . $path/vpn_log.sh "Tunnel down! Restarting OpenVPN"
  service openvpn restart
fi
