#!/bin/sh

D=`date "+%Y-%m-%d %H:%M"`
echo "$D ($local_port_1:$proto_1) $X509_0_CN: $trusted_ip => $ifconfig_pool_remote_ip" >> /etc/openvpn/client-connected.log
