#!/bin/bash

cd /etc/openvpn/easy-rsa/
./easyrsa --batch revoke $1
./easyrsa gen-crl
rm -rf pki/reqs/$1.req
 rm -rf pki/private/$1.key
 rm -rf pki/issued/$1.crt
 rm -rf /etc/openvpn/crl.pem
 rm /etc/openvpn/clients/$1.ovpn
 cp /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn/crl.pem

