#!/bin/bash
#
#<UDF name="ssuser" Label="Sudo user username?" example="username" />
#<UDF name="sspassword" Label="Sudo user password?" example="strongPassword" />
#<UDF name="sspubkey" Label="SSH pubkey (installed for root and sudo user)?" example="ssh-rsa ..." />
#
# Works for CentOS 7

if [[ ! $SSUSER ]]; then read -p "Sudo user username?" SSUSER; fi
if [[ ! $SSPASSWORD ]]; then read -p "Sudo user password?" SSPASSWORD; fi
if [[ ! $SSPUBKEY ]]; then read -p "SSH pubkey (installed for root and sudo user)?" SSPUBKEY; fi

# set up sudo user
echo Setting sudo user: $SSUSER...
useradd $SSUSER && echo $SSPASSWORD | passwd $SSUSER --stdin
usermod -aG wheel $SSUSER
echo ...done
# sudo user complete

# disable password and root over ssh
echo Disabling SSH
systemctl disable sshd.service 
echo ...done

#remove unneeded services
echo Removing unneeded services...
yum remove -y avahi chrony
echo ...done

# Initial needfuls
yum update -y
yum install mc bind-utils psmisc bash-completion chrony wget policycoreutils-python setools-console yum-cron git nmap epel-release
yum update -y

# Set up automatic  updates
echo Setting up automatic updates...
sed -i.orig 's/apply_updates = no/apply_updates = yes/g' /etc/yum/yum-cron.conf
systemctl enable yum-cron.service
systemctl restart yum-cron.service
echo ...done
# auto-updates complete

#set up fail2ban
echo Setting up fail2ban...
yum install -y fail2ban
cd /etc/fail2ban
cp fail2ban.conf fail2ban.local
cp jail.conf jail.local
sed -i -e "s/backend = auto/backend = systemd/" /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl start fail2ban
echo ...done

# stop firewalld - use iptables
systemctl stop firewalld
systemctl mask firewalld
yum install iptables-services
systemctl enable iptables
systemctl start iptables
service iptables save

# secure against attacks
iptables -F

# Block incoming on eth0
iptables -A OUTPUT -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp --sport 80 -m state --state ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp --sport 443 -m state --state ESTABLISHED -j ACCEPT

# Allow DNS
iptables -A OUTPUT -p udp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -p udp --sport 53 -m state --state ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp --sport 53 -m state --state ESTABLISHED -j ACCEPT

# accept outbound connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow incoming on eth1 (for PostgresSQL port)
iptables -A INPUT -i eth1 -p tcp --dport 5432 -j ACCEPT

# Block everything by default
iptables -j INPUT -i eth0 -j DROP
iptables -j INPUT -i eth1 -j DROP

iptables-save | sudo tee /etc/sysconfig/iptables
service iptables restart

echo ...done
echo ...use 'ss -lntu' to see which ports are open 


#setup date and time
cd /etc
rm localtime
ln -s /usr/share/zoneinfo/US/Pacific localtime

# ensure ntp is installed and running
yum install -y ntp
systemctl enable ntpd
systemctl start ntpd

#
echo All finished! Rebooting...
(sleep 5; reboot) &