#!/usr/local/bin/bash
# OpenVPN up script
# Makes a non-blocking call to the actual script port forwarding script.
path="/opt/openvpn"

running=$(./vpn_isrunning.sh)
if [ $running -eq 1 ]; then
  . $path/vpn_request.sh &
fi
