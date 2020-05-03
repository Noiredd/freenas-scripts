#!/usr/local/bin/bash
# Check whether the script should be halted
# Checks for presence of a `stop.it` file,
# returns 1 for non-present ("running") and
# 0 for present ("stop").
path="/opt/openvpn"
stopfile=stop.it

if [ -e $path/$stopfile ]; then
  echo 0
else
  echo 1
fi
