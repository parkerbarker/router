
# Router

```bash
# Update and upgrade system
echo "Updating and upgrading system..."
sudo apt update && sudo apt upgrade -y

# Configure network interfaces
echo "Configuring network interfaces..."
sudo tee /etc/netplan/01-netcfg.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp3s0:
      dhcp4: true
    enp4s0:
      dhcp4: false
      addresses:
        - 10.0.0.1/24
EOF
sudo chmod 600 /etc/netplan/01-netcfg.yaml
sudo netplan apply

# Enable IP forwarding
echo "Enabling IP forwarding..."
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv4.conf.all.send_redirects=0
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
sudo sysctl -p

# Install necessary packages
echo "Installing necessary packages..."
sudo apt install -y nftables isc-dhcp-server unbound iftop

# Configure nftables for NAT and filtering
echo "Configuring nftables for NAT and filtering..."
sudo tee /etc/nftables.conf > /dev/null <<EOF
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        # Allow loopback traffic
        iif lo accept

        # Allow established/related connections
        ct state established,related accept

        # Allow ICMP (Ping)
        ip protocol icmp accept

        # Allow incoming DNS queries
        ip daddr 10.0.0.1 udp dport 53 accept
        ip daddr 10.0.0.1 tcp dport 53 accept

        # Allow SSH
        ip daddr 10.0.0.1 tcp dport 22 accept

        # Log and drop invalid packets
        ct state invalid log prefix "Dropped: " group 0 drop
    }

    chain forward {
        type filter hook forward priority 0; policy drop;

        # Allow traffic from LAN to WAN
        iif "enp4s0" oif "enp3s0" accept

        # Allow established/related connections
        ct state established,related accept
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}

table ip nat {
    chain prerouting {
        type nat hook prerouting priority -100;
    }

    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        oif "enp3s0" masquerade
    }
}
EOF

# Apply nftables rules
echo "Applying nftables rules..."
sudo nft -f /etc/nftables.conf
sudo systemctl start nftables
sudo systemctl enable nftables
sudo systemctl status nftables

# Configure systemd-resolved for DNS
echo "Configuring systemd-resolved for DNS..."
sudo tee /etc/systemd/resolved.conf > /dev/null <<EOF
[Resolve]
DNS=1.1.1.1
FallbackDNS=8.8.8.8
EOF
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Configure DHCP server
echo "Configuring DHCP server..."
sudo tee /etc/dhcp/dhcpd.conf > /dev/null <<EOF
option domain-name "mydomain.com";
option domain-name-servers 1.1.1.1;

default-lease-time 600;
max-lease-time 7200;

ddns-update-style none;

authoritative;

subnet 10.0.0.0 netmask 255.255.255.0 {
    range 10.0.0.10 10.0.0.150;
    option subnet-mask 255.255.255.0;
    option routers 10.0.0.1;
    option domain-name-servers 1.1.1.1;
}
EOF
sudo systemctl restart isc-dhcp-server

# # Configure Unbound for DNS caching
# echo "Configuring Unbound for DNS caching..."
# sudo tee /etc/unbound/unbound.conf > /dev/null <<EOF
# server:
#     interface: 0.0.0.0
#     access-control: 10.0.0.0/24 allow
#     do-not-query-localhost: no

# forward-zone:
#     name: "."
#     forward-addr: 1.1.1.1
#     forward-addr: 8.8.8.8
# EOF
# sudo systemctl restart unbound

# # Monitor network traffic
# echo "Network monitoring available with iftop. Run: sudo iftop -i enp3s0"


sudo apt-get install software-properties-common
sudo apt install -y suricata suricata-update
# sudo suricata-update
```
