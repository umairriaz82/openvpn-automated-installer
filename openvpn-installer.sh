#!/bin/bash

# defaults
DNS1="8.8.8.8"
DNS2="8.8.4.4"
PROTOCOL=udp
PORT=1194
publicIP=$(wget -4qO- "http://whatismyip.akamai.com/")

clear

function installUnbound() {
	# If Unbound isn't installed, install it
	if [[ ! -e /etc/unbound/unbound.conf ]]; then

		if [[ $OS =~ (debian|ubuntu) ]]; then
			apt-get install -y unbound

			# Configuration
			echo 'interface: 10.8.0.1
			access-control: 10.8.0.1/24 allow
			hide-identity: yes
			hide-version: yes
			use-caps-for-id: yes
			prefetch: yes' >>/etc/unbound/unbound.conf

		elif [[ $OS =~ (centos|amzn) ]]; then
			yum install -y unbound

			# Configuration
			sed -i 's|# interface: 0.0.0.0$|interface: 10.8.0.1|' /etc/unbound/unbound.conf
			sed -i 's|# access-control: 127.0.0.0/8 allow|access-control: 10.8.0.1/24 allow|' /etc/unbound/unbound.conf
			sed -i 's|# hide-identity: no|hide-identity: yes|' /etc/unbound/unbound.conf
			sed -i 's|# hide-version: no|hide-version: yes|' /etc/unbound/unbound.conf
			sed -i 's|use-caps-for-id: no|use-caps-for-id: yes|' /etc/unbound/unbound.conf

		elif [[ $OS == "fedora" ]]; then
			dnf install -y unbound

			# Configuration
			sed -i 's|# interface: 0.0.0.0$|interface: 10.8.0.1|' /etc/unbound/unbound.conf
			sed -i 's|# access-control: 127.0.0.0/8 allow|access-control: 10.8.0.1/24 allow|' /etc/unbound/unbound.conf
			sed -i 's|# hide-identity: no|hide-identity: yes|' /etc/unbound/unbound.conf
			sed -i 's|# hide-version: no|hide-version: yes|' /etc/unbound/unbound.conf
			sed -i 's|# use-caps-for-id: no|use-caps-for-id: yes|' /etc/unbound/unbound.conf

		elif [[ $OS == "arch" ]]; then
			pacman -Syu --noconfirm unbound

			# Get root servers list
			curl -o /etc/unbound/root.hints https://www.internic.net/domain/named.cache

			if [[ ! -f /etc/unbound/unbound.conf.old ]]; then
				mv /etc/unbound/unbound.conf /etc/unbound/unbound.conf.old
			fi

			echo 'server:
			use-syslog: yes
			do-daemonize: no
			username: "unbound"
			directory: "/etc/unbound"
			trust-anchor-file: trusted-key.key
			root-hints: root.hints
			interface: 10.8.0.1
			access-control: 10.8.0.1/24 allow
			port: 53
			num-threads: 2
			use-caps-for-id: yes
			harden-glue: yes
			hide-identity: yes
			hide-version: yes
			qname-minimisation: yes
			prefetch: yes' >/etc/unbound/unbound.conf
		fi

		# IPv6 DNS for all OS
		if [[ $IPV6_SUPPORT == 'y' ]]; then
			echo 'interface: fd42:42:42:42::1
			access-control: fd42:42:42:42::/112 allow' >>/etc/unbound/unbound.conf
		fi

		if [[ ! $OS =~ (fedora|centos|amzn) ]]; then
			# DNS Rebinding fix
			echo "private-address: 10.0.0.0/8
			private-address: fd42:42:42:42::/112
			private-address: 172.16.0.0/12
			private-address: 192.168.0.0/16
			private-address: 169.254.0.0/16
			private-address: fd00::/8
			private-address: fe80::/10
			private-address: 127.0.0.0/8
			private-address: ::ffff:0:0/96" >>/etc/unbound/unbound.conf
		fi
	else # Unbound is already installed
		echo 'include: /etc/unbound/openvpn.conf' >>/etc/unbound/unbound.conf

		# Add Unbound 'server' for the OpenVPN subnet
		echo 'server:
		interface: 10.8.0.1
		access-control: 10.8.0.1/24 allow
		hide-identity: yes
		hide-version: yes
		use-caps-for-id: yes
		prefetch: yes
		private-address: 10.0.0.0/8
		private-address: fd42:42:42:42::/112
		private-address: 172.16.0.0/12
		private-address: 192.168.0.0/16
		private-address: 169.254.0.0/16
		private-address: fd00::/8
		private-address: fe80::/10
		private-address: 127.0.0.0/8
		private-address: ::ffff:0:0/96' >/etc/unbound/openvpn.conf
		if [[ $IPV6_SUPPORT == 'y' ]]; then
			echo 'interface: fd42:42:42:42::1
			access-control: fd42:42:42:42::/112 allow' >>/etc/unbound/openvpn.conf
		fi
	fi

	systemctl enable unbound
	systemctl restart unbound
}

echo "$(tput setaf 2)*****************************************************************"
echo "*               OpenVPN Automated Installer                     *"
echo "*****************************************************************$(tput sgr 0)"
echo ""
# Detect Debian users running the script with "sh" instead of bash
if readlink /proc/$$/exe | grep -qs "dash"; then
	echo "     $(tput setaf 1)This script needs to be run with bash, not sh$(tput sgr 0)"
	echo ""
	exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
	echo "           $(tput setaf 1)Sorry, you need to run this as root$(tput sgr 0)"
	echo ""
	exit 2
fi

if [[ ! -e /dev/net/tun ]]; then
	echo "$(tput setaf 1)The TUN device is not available. You need to enable TUN before running this script.$(tput sgr 0)"
	echo ""
	exit 3
fi

if grep -qs "CentOS release 5" "/etc/redhat-release"; then
	echo "             $(tput setaf 1)CentOS 5 is too old and not supported$(tput sgr 0)"
	echo ""
	exit 4
fi

if [[ -e /etc/debian_version ]]; then
	OS=debian
	GROUPNAME=nogroup
	RCLOCAL='/etc/rc.local'
elif [[ -e /etc/centos-release || -e /etc/redhat-release ]]; then
	OS=centos
	GROUPNAME=nobody
	RCLOCAL='/etc/rc.d/rc.local'
else
	echo "    $(tput setaf 1)Looks like you aren't running this installer on Debian, Ubuntu or CentOS$(tput sgr 0)"
	exit 5
fi
echo ""
until [[ $ADMINPASSWORD != "" ]]; do
	read -rp "    $(tput setaf 2)$(echo -e '\U0002705') Admin GUI Password:$(tput sgr 0)    " -e ADMINPASSWORD
done

until [[ $HOST != "" ]]; do
	read -rp "    $(tput setaf 2)$(echo -e '\U0002705') Server IP or Hostname:$(tput sgr 0) " -e -i "$publicIP" HOST
done

echo "    $(tput setaf 2)$(echo -e '\U0002705') Connection Protocol:$(tput sgr 0)   $PROTOCOL"
echo "    $(tput setaf 2)$(echo -e '\U0002705') Connection Port:$(tput sgr 0)       $PORT"
echo "    $(tput setaf 2)$(echo -e '\U0002705') DNS Server 1:$(tput sgr 0)          $DNS1"
echo "    $(tput setaf 2)$(echo -e '\U0002705') DNS Server 2:$(tput sgr 0)          $DNS2"

echo ""
echo "    $(tput setaf 2)$(echo -e '\U0002705') Select Deployment:$(tput sgr 0)"
echo "   	$(tput setaf 3)1) Default $(tput sgr 0)"
echo "   	$(tput setaf 3)2) Custom $(tput sgr 0)"
echo ""
until [[ $deploy_CHOICE =~ ^[1-2]$ ]]; do
	read -rp "        $(tput setaf 3)Deployment choice [1-2]: $(tput sgr 0)" -e -i 1 deploy_CHOICE
done

if [[ "$deploy_CHOICE" == 1 ]]; then
	echo 'We will proceed with default options for the openvpn deployment'
else
	echo ""
	echo "    $(tput setaf 2)$(echo -e '\U0002705') What port do you want OpenVPN to listen to?$(tput sgr 0)"
	echo "        $(tput setaf 3)1) Default: 1194"
	echo "        2) Custom"
	echo "        3) Random [49152-65535]"
	echo ""
	until [[ $PORT_CHOICE =~ ^[1-3]$ ]]; do
		read -rp "        Port choice [1-3]: $(tput sgr 0)" -e -i 1 PORT_CHOICE
	done
	echo ""
	case $PORT_CHOICE in
		1)
		PORT="1194"
		echo $PORT
		;;
		2)
		PORT=""
		until [[ $PORT =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; do
			read -rp "        $(tput setaf 3)Custom port [1-65535]: $(tput sgr 0)" -e -i 1194 PORT
		done
		echo $PORT
		;;
		3)
		# Generate random number within private ports range
		PORT=$(shuf -i49152-65535 -n1)
		echo "        $(tput setaf 3)Random Port Selected:$(tput sgr 0) $PORT"
		;;
	esac
	echo ""
	echo "     $(tput setaf 2)$(echo -e '\U0002705') What protocol do you want OpenVPN to use?$(tput sgr 0)"

	echo "        $(tput setaf 3)1) UDP (Recommended)$(tput sgr 0)"
	echo "        $(tput setaf 3)2) TCP"
	echo ""
	until [[ $PROTOCOL_CHOICE =~ ^[1-2]$ ]]; do
		read -rp "        Protocol [1-2]: $(tput sgr 0)" -e -i 1 PROTOCOL_CHOICE
	done
	case $PROTOCOL_CHOICE in
		1)
		PROTOCOL="udp"
		echo $PROTOCOL
		;;
		2)
		PROTOCOL="tcp"
		;;
	esac



	echo ""
	echo "What DNS resolvers do you want to use with the VPN?"
	echo "   1) Current system resolvers (from /etc/resolv.conf)"
	echo "   2) Self-hosted DNS Resolver (Unbound)"
	echo "   3) Cloudflare (Anycast: worldwide)"
	echo "   4) Quad9 (Anycast: worldwide)"
	echo "   5) Quad9 uncensored (Anycast: worldwide)"
	echo "   6) FDN (France)"
	echo "   7) DNS.WATCH (Germany)"
	echo "   8) OpenDNS (Anycast: worldwide)"
	echo "   9) Google (Anycast: worldwide)"
	echo "   10) Yandex Basic (Russia)"
	echo "   11) AdGuard DNS (Anycast: worldwide)"
	echo "   12) NextDNS (Anycast: worldwide)"
	echo "   13) Custom"
	until [[ $DNS =~ ^[0-9]+$ ]] && [ "$DNS" -ge 1 ] && [ "$DNS" -le 13 ]; do
		read -rp "DNS [1-12]: " -e -i 3 DNS
		if [[ $DNS == 2 ]] && [[ -e /etc/unbound/unbound.conf ]]; then
			echo ""
			echo "Unbound is already installed."
			echo "You can allow the script to configure it in order to use it from your OpenVPN clients"
			echo "We will simply add a second server to /etc/unbound/unbound.conf for the OpenVPN subnet."
			echo "No changes are made to the current configuration."
			echo ""

			until [[ $CONTINUE =~ (y|n) ]]; do
				read -rp "Apply configuration changes to Unbound? [y/n]: " -e CONTINUE
			done
			if [[ $CONTINUE == "n" ]]; then
				# Break the loop and cleanup
				unset DNS
				unset CONTINUE
			fi
		elif [[ $DNS == "13" ]]; then
			until [[ $DNS1 =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; do
				read -rp "Primary DNS: " -e DNS1
			done
			until [[ $DNS2 =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; do
				read -rp "Secondary DNS (optional): " -e DNS2
				if [[ $DNS2 == "" ]]; then
					break
				fi
			done
		fi
	done
fi
# Try to get our IP from the system and fallback to the Internet.
if [[ $DNS == 2 ]]; then
	installUnbound
fi

IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
if [[ "$IP" = "" ]]; then
	IP=$(wget -4qO- "http://whatismyip.akamai.com/")
fi



if [[ "$OS" = 'debian' ]]; then
	apt-get update
	apt-get install openvpn iptables openssl ca-certificates lighttpd -y
else
	# Else, the distro is CentOS
	yum install epel-release -y
	yum install openvpn iptables openssl wget ca-certificates lighttpd -y
fi

# An old version of easy-rsa was available by default in some openvpn packages
if [[ -d /etc/openvpn/easy-rsa/ ]]; then
	rm -rf /etc/openvpn/easy-rsa/
fi
# Get easy-rsa

wget -O ~/EasyRSA-3.0.1.tgz "https://github.com/OpenVPN/easy-rsa/releases/download/3.0.1/EasyRSA-3.0.1.tgz"
tar xzf ~/EasyRSA-3.0.1.tgz -C ~/
mv ~/EasyRSA-3.0.1/ /etc/openvpn/
mv /etc/openvpn/EasyRSA-3.0.1/ /etc/openvpn/easy-rsa/
chown -R root:root /etc/openvpn/easy-rsa/
rm -rf ~/EasyRSA-3.0.1.tgz
cd /etc/openvpn/easy-rsa/

# Create the PKI, set up the CA, the DH params and the server + client certificates
./easyrsa init-pki
./easyrsa --batch build-ca nopass
./easyrsa gen-dh
./easyrsa build-server-full server nopass

# ./easyrsa build-client-full $CLIENT nopass
./easyrsa gen-crl

# Move the stuff we need
cp pki/ca.crt pki/private/ca.key pki/dh.pem pki/issued/server.crt pki/private/server.key /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn

# CRL is read with each client connection, when OpenVPN is dropped to nobody
chown nobody:$GROUPNAME /etc/openvpn/crl.pem

# Generate key for tls-auth
openvpn --genkey --secret /etc/openvpn/ta.key

# Generate server.conf
echo "port $PORT
proto $PROTOCOL
dev tun
sndbuf 0
rcvbuf 0
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt" > /etc/openvpn/server.conf
echo 'push "redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/server.conf

# DNS
case $DNS in
	1) # Current system resolvers
	# Locate the proper resolv.conf
	# Needed for systems running systemd-resolved
	if grep -q "127.0.0.53" "/etc/resolv.conf"; then
		RESOLVCONF='/run/systemd/resolve/resolv.conf'
	else
		RESOLVCONF='/etc/resolv.conf'
	fi
	# Obtain the resolvers from resolv.conf and use them for OpenVPN
	sed -ne 's/^nameserver[[:space:]]\+\([^[:space:]]\+\).*$/\1/p' $RESOLVCONF | while read -r line; do
		# Copy, if it's a IPv4 |or| if IPv6 is enabled, IPv4/IPv6 does not matter
		if [[ $line =~ ^[0-9.]*$ ]] || [[ $IPV6_SUPPORT == 'y' ]]; then
			echo "push \"dhcp-option DNS $line\"" >>/etc/openvpn/server.conf
		fi
	done
	;;
	2) # Self-hosted DNS resolver (Unbound)
	echo 'push "dhcp-option DNS 10.8.0.1"' >>/etc/openvpn/server.conf
	if [[ $IPV6_SUPPORT == 'y' ]]; then
		echo 'push "dhcp-option DNS fd42:42:42:42::1"' >>/etc/openvpn/server.conf
	fi
	;;
	3) # Cloudflare
	echo 'push "dhcp-option DNS 1.0.0.1"' >>/etc/openvpn/server.conf
	echo 'push "dhcp-option DNS 1.1.1.1"' >>/etc/openvpn/server.conf
	;;
	4) # Quad9
	echo 'push "dhcp-option DNS 9.9.9.9"' >>/etc/openvpn/server.conf
	echo 'push "dhcp-option DNS 149.112.112.112"' >>/etc/openvpn/server.conf
	;;
	5) # Quad9 uncensored
	echo 'push "dhcp-option DNS 9.9.9.10"' >>/etc/openvpn/server.conf
	echo 'push "dhcp-option DNS 149.112.112.10"' >>/etc/openvpn/server.conf
	;;
	6) # FDN
	echo 'push "dhcp-option DNS 80.67.169.40"' >>/etc/openvpn/server.conf
	echo 'push "dhcp-option DNS 80.67.169.12"' >>/etc/openvpn/server.conf
	;;
	7) # DNS.WATCH
	echo 'push "dhcp-option DNS 84.200.69.80"' >>/etc/openvpn/server.conf
	echo 'push "dhcp-option DNS 84.200.70.40"' >>/etc/openvpn/server.conf
	;;
	8) # OpenDNS
	echo 'push "dhcp-option DNS 208.67.222.222"' >>/etc/openvpn/server.conf
	echo 'push "dhcp-option DNS 208.67.220.220"' >>/etc/openvpn/server.conf
	;;
	9) # Google
	echo 'push "dhcp-option DNS 8.8.8.8"' >>/etc/openvpn/server.conf
	echo 'push "dhcp-option DNS 8.8.4.4"' >>/etc/openvpn/server.conf
	;;
	10) # Yandex Basic
	echo 'push "dhcp-option DNS 77.88.8.8"' >>/etc/openvpn/server.conf
	echo 'push "dhcp-option DNS 77.88.8.1"' >>/etc/openvpn/server.conf
	;;
	11) # AdGuard DNS
	echo 'push "dhcp-option DNS 176.103.130.130"' >>/etc/openvpn/server.conf
	echo 'push "dhcp-option DNS 176.103.130.131"' >>/etc/openvpn/server.conf
	;;
	12) # NextDNS
	echo 'push "dhcp-option DNS 45.90.28.167"' >>/etc/openvpn/server.conf
	echo 'push "dhcp-option DNS 45.90.30.167"' >>/etc/openvpn/server.conf
	;;
	13) # Custom DNS
	echo "push \"dhcp-option DNS $DNS1\"" >>/etc/openvpn/server.conf
	if [[ $DNS2 != "" ]]; then
		echo "push \"dhcp-option DNS $DNS2\"" >>/etc/openvpn/server.conf
	fi
	;;
esac
echo "keepalive 10 120
cipher AES-256-CBC

user nobody
group $GROUPNAME
persist-key
persist-tun
status openvpn-status.log
verb 3
crl-verify crl.pem" >> /etc/openvpn/server.conf

# Enable net.ipv4.ip_forward for the system
sed -i '/\<net.ipv4.ip_forward\>/c\net.ipv4.ip_forward=1' /etc/sysctl.conf
if ! grep -q "\<net.ipv4.ip_forward\>" /etc/sysctl.conf; then
	echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
fi

# Avoid an unneeded reboot
echo 1 > /proc/sys/net/ipv4/ip_forward
if pgrep firewalld; then
	# Using both permanent and not permanent rules to avoid a firewalld
	# reload.
	# We don't use --add-service=openvpn because that would only work with
	# the default port and protocol.
	firewall-cmd --zone=public --add-port=$PORT/$PROTOCOL
	firewall-cmd --zone=trusted --add-source=10.8.0.0/24
	firewall-cmd --permanent --zone=public --add-port=$PORT/$PROTOCOL
	firewall-cmd --permanent --zone=trusted --add-source=10.8.0.0/24
	# Set NAT for the VPN subnet
	firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 -j SNAT --to $IP
	firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 -j SNAT --to $IP
else
	# Needed to use rc.local with some systemd distros
	if [[ "$OS" = 'debian' && ! -e $RCLOCAL ]]; then
		echo '#!/bin/sh -e
		exit 0' > $RCLOCAL
	fi
	chmod +x $RCLOCAL
	# Set NAT for the VPN subnet
	iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to $IP
	sed -i "1 a\iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to $IP" $RCLOCAL
	if iptables -L -n | grep -qE '^(REJECT|DROP)'; then
		# If iptables has at least one REJECT rule, we asume this is needed.
		# Not the best approach but I can't think of other and this shouldn't
		# cause problems.
		iptables -I INPUT -p $PROTOCOL --dport $PORT -j ACCEPT
		iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT
		iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
		sed -i "1 a\iptables -I INPUT -p $PROTOCOL --dport $PORT -j ACCEPT" $RCLOCAL
		sed -i "1 a\iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT" $RCLOCAL
		sed -i "1 a\iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT" $RCLOCAL
	fi
fi
# If SELinux is enabled and a custom port or TCP was selected, we need this
if hash sestatus 2>/dev/null; then
	if sestatus | grep "Current mode" | grep -qs "enforcing"; then
		if [[ "$PORT" != '1194' || "$PROTOCOL" = 'tcp' ]]; then
			# semanage isn't available in CentOS 6 by default
			if ! hash semanage 2>/dev/null; then
				yum install policycoreutils-python -y
			fi
			semanage port -a -t openvpn_port_t -p $PROTOCOL $PORT
		fi
	fi
fi

# And finally, restart OpenVPN
if [[ "$OS" = 'debian' ]]; then
	# Little hack to check for systemd
	if pgrep systemd-journal; then
		systemctl restart openvpn@server.service
	else
		/etc/init.d/openvpn restart
	fi
else
	if pgrep systemd-journal; then
		systemctl restart openvpn@server.service
		systemctl enable openvpn@server.service
	else
		service openvpn restart
		chkconfig openvpn on
	fi
fi

# Try to detect a NATed connection and ask about it to potential LowEndSpirit users


# client-common.txt is created so we have a template to add further users later
echo "client
dev tun
proto $PROTOCOL
sndbuf 0
rcvbuf 0
remote $HOST $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
setenv opt block-outside-dns
key-direction 1
verb 3" > /etc/openvpn/client-common.txt

# Generates the custom client.ovpn
mv /etc/openvpn/clients/ /etc/openvpn/clients.$$/
mkdir /etc/openvpn/clients/

#Setup the web server to use an self signed cert
# mkdir /etc/openvpn/clients/

#Set permissions for easy-rsa and open vpn to be modified by the web user.
chown -R www-data:www-data /etc/openvpn/easy-rsa
chown -R www-data:www-data /etc/openvpn/clients/
chmod -R 755 /etc/openvpn/
chmod -R 777 /etc/openvpn/crl.pem
chmod g+s /etc/openvpn/clients/
chmod g+s /etc/openvpn/easy-rsa/

#Generate a self-signed certificate for the web server
mv /etc/lighttpd/ssl/ /etc/lighttpd/ssl.$$/
mkdir /etc/lighttpd/ssl/
openssl req -new -x509 -keyout /etc/lighttpd/ssl/server.pem -out /etc/lighttpd/ssl/server.pem -days 9999 -nodes -subj "/C=US/ST=California/L=San Francisco/O=example.com/OU=Ops Department/CN=example.com"
chmod 744 /etc/lighttpd/ssl/server.pem


#Configure the web server with the lighttpd.conf from GitHub
mv /etc/lighttpd/lighttpd.conf /etc/lighttpd/lighttpd.conf.$$
wget -O /etc/lighttpd/lighttpd.conf https://raw.githubusercontent.com/umairriaz82/openvpn-automated-installer/master/lighttpd.conf

#install the webserver scripts
rm /var/www/html/*
wget -O /var/www/html/index.sh https://raw.githubusercontent.com/umairriaz82/openvpn-automated-installer/master/index.sh

wget -O /var/www/html/download.sh https://raw.githubusercontent.com/umairriaz82/openvpn-automated-installer/master/download.sh
chown -R www-data:www-data /var/www/html/

#set the password file for the WWW logon
echo "admin:$ADMINPASSWORD" >> /etc/lighttpd/.lighttpdpassword

#restart the web server
service lighttpd restart

clear
echo "$(tput setaf 2)*****************************************************************"
echo "*               OpenVPN Server Successfully Installed           *"
echo "*****************************************************************"
echo ""
echo "       To access Admin GUI, visit:  https://$HOST "
echo "                 Username: admin"
echo "                 Password: $ADMINPASSWORD"
echo ""
echo "       Make sure you allow $PROTOCOL traffic on port $PORT"
echo ""
echo "*****************************************************************$(tput sgr 0)"
