sudo ip netns add vm2
sudo ip link add veth0 type veth peer name veth1
sudo ip link set veth1 netns vm2

sudo ip addr add 192.168.50.1/24 dev veth0
sudo ip link set veth0 up

sudo ip netns exec vm2 ip link set lo up
sudo ip netns exec vm2 ip link set veth1 up

# PART 1 — DHCP SERVER

sudo apt update
sudo apt install -y isc-dhcp-server

sudo tee /etc/dhcp/dhcpd.conf <<EOF
default-lease-time 3600;
max-lease-time 7200;
authoritative;

subnet 192.168.50.0 netmask 255.255.255.0 {
    range 192.168.50.100 192.168.50.200;
    option routers 192.168.50.1;
    option domain-name-servers 8.8.8.8, 1.1.1.1;
}
EOF

sudo sed -i 's|INTERFACESv4=""|INTERFACESv4="veth0"|' /etc/default/isc-dhcp-server
sudo systemctl restart isc-dhcp-server
sudo systemctl enable isc-dhcp-server

sudo ip netns exec vm2 dhclient veth1
sudo ip netns exec vm2 ip a

# PART 2 — NAT + INTERNET

sudo sysctl -w net.ipv4.ip_forward=1

sudo apt install -y iptables iptables-persistent

sudo iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o end33 -j MASQUERADE
sudo iptables -A FORWARD -i end33 -o veth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i veth0 -o end33 -j ACCEPT

sudo netfilter-persistent save

# PART 3 — FIREWALL (iptables, no ufw)

sudo iptables -F INPUT
sudo iptables -P INPUT DROP
sudo iptables -P OUTPUT ACCEPT

sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT

sudo netfilter-persistent save

# PART 4 — SSH KEYS (vm2 -> main)

sudo ip netns exec vm2 mkdir -p /home/ubuntu/.ssh
sudo ip netns exec vm2 ssh-keygen -t ed25519 -f /home/ubuntu/.ssh/id_ed25519 -N ""
sudo ip netns exec vm2 ssh-keyscan 192.168.50.1 >> /home/ubuntu/.ssh/known_hosts

# copy key to main vm
sudo ip netns exec vm2 ssh-copy-id -i /home/ubuntu/.ssh/id_ed25519.pub ubuntu@192.168.50.1

# PART 5 — NGINX (service check)

sudo apt install -y nginx
sudo systemctl enable --now nginx

# PART 6 — BACKUP VIA RSYNC

sudo mkdir -p /backups/etc
sudo chown ubuntu:ubuntu /backups/etc

sudo ip netns exec vm2 rsync -azhAX -e "ssh -i /home/ubuntu/.ssh/id_ed25519" \
/etc/ ubuntu@192.168.50.1:/backups/etc/

# PART 7 — CRON

( sudo crontab -l 2>/dev/null; echo \
'0 2 * * * /usr/bin/rsync -azhAX --delete /etc/ /backups/etc/ >> /var/log/backup-rsync.log 2>&1' ) \
| sudo crontab -

# PART 8 — TAR LOG ARCHIVES

sudo mkdir -p /backups/logs
sudo tar -czvf /backups/logs/logs_$(date +%F).tar.gz /var/log

# PART 9 — CHECKS

sudo ip netns exec vm2 ping -c 2 8.8.8.8
sudo ss -tulpn | grep -E '22|80'
ls -lh /backups/etc/
ls -lh /backups/logs/
sudo ip netns exec vm2 ssh ubuntu@192.168.50.1 "hostname"
