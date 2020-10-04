#!/bin/sh

D=`date "+%b-%d-%Y %H:%M"`
echo "$D ($local_port_1:$proto_1) $X509_0_CN: $trusted_ip => $ifconfig_pool_remote_ip" >> /etc/openvpn/client-disconnected.log
