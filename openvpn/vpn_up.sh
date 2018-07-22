#!/usr/local/bin/bash
# OpenVPN up script
# Makes a non-blocking call to the actual script port forwarding script.
path="/usr/local/etc/openvpn"
. $path/vpn_request.sh &
