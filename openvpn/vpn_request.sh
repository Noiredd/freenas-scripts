#!/usr/local/bin/bash
# Requests a port from PIA and stores its number in a specific file.
# A periodic cron job must be set up with another script to scan for that file
# and do the rest of the job.
path="/opt/openvpn"

port_request () {
  client_id=`head -n 100 /dev/urandom | shasum -a 256 | tr -d " -"`
  json=`curl "http://209.222.18.222:2000/\?client_id=$client_id" 2>/dev/null`
  if [ "$json" == "" ]; then
    json='Port forwarding is already activated on this connection, has expired, or you are not connected to a PIA region that supports port forwarding'
    . $path/vpn_log.sh $json
    exit
  fi
  port=$(echo $json | python2.7 -c 'import sys;exec("j="+sys.stdin.read());print j["port"]')
  echo $port > $path/port.id
}

sleep 10 # just enough to let openvpn finish setting connection - never >=120
port_request
