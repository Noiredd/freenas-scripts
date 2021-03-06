#!/usr/local/bin/bash
# Logs timestamped custom messages to a given file (if any).
path="/opt/openvpn"

if [ -f $path/notify.path ]; then
  destination=$(cat $path/notify.path)
  echo $(date) $1 >> $destination
fi
