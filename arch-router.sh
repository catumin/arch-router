#!/bin/bash

set -e

if [ "$#" -ne 1 ]; then
    echo "Need two arguments. The first is the external interface, the second is the interface that will provide networking."
    echo "For example: ./arch-router wlp3s0 enp1s0"
    echo "Will pass connection from the wifi interface to the wired."

    exit 1
fi

echo "Installing needed dependencies"
sudo systemctl -S netctl dnsmasq iptables

sudo tee /etc/netctl/$2-profile <<EOF
Description='Private Interface'
Interface=$
Connection=ethernet
IP='static'
Address=('10.0.0.1/24')
EOF

echo "Enabling and starting $1 interface"
sudo netctl enable $2-profile
sudo netctl start $2-profile

sudo tee -a /etc/dnsmasq.conf <<EOF
interface=$2
expand-hosts
domain=foo.bar
dhcp-range=10.0.0.2,10.0.0.255,255.255.255.0,1h
EOF

echo "Starting iptables"
sudo systemctl start iptables

sudo tee -a /etc/iptables/iptables.rule <<EOF
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o $1 -j MASQUERADE
COMMIT


*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i $2 -o $1 -j ACCEPT
COMMIT
EOF

echo "Restarting and enabling iptables. Same with dnsmasq"
sudo systemctl restart iptables
sudo systemctl enable iptables
sudo systemctl start dnsmasq
sudo systemctl enable dnsmasq

echo "Your system should now be router traffic from $1 to $2, and is also acting as a DNS and DHCP server for devices attached to $2."
