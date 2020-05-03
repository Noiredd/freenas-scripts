#!/usr/local/bin/bash
# Requests a port from PIA and stores its number in a specific file.
# A periodic cron job must be set up with another script to scan for that file
# and do the rest of the job.
path="/opt/openvpn"

port_request () {
  # The following is the recommended solution but I didn't have shasum installed
  # client_id=`head -n 100 /dev/urandom | shasum -a 256 | tr -d " -"`
  client_id=`head -n 100 /dev/urandom | sha1`
  json=`curl "http://209.222.18.222:2000/\?client_id=$client_id" 2>/dev/null`
  if [ "$json" == "" ]; then
    msg='Port forwarding is already activated on this connection, has expired, or you are not connected to a PIA region that supports port forwarding'
    . $path/vpn_log.sh $msg
    exit
  fi
  port=`echo $json | jq -r '.port'`
  echo $port > $path/port.id
}

sleep 10 # just enough to let openvpn finish setting connection - never >=120
port_request
