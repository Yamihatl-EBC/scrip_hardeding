#!/bin/bash
yum clean all
yum update -y
yum install -y wget 
yum install -y policycoreutils-python
yum install -y firewalld 
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --zone=public --add-port=22222/tcp
firewall-cmd --permanent --zone=public --add-port=443/tcp
firewall-cmd --permanent --zone=public --add-port=161/tcp
firewall-cmd --reload
systemctl enable tmp.mount
mv /etc/issue /etc/issue.rnew
cd /etc/
wget https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/issue
chmod 0600 /etc/issue 
mv /etc/ssh/sshd_config /etc/ssh/ssh_config.new
cd /etc/ssh/     
wget https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/sshd_config
chmod 0600 /etc/ssh/sshd_config
semanage port –a –t ssh_port_t –p tcp 22222
systemctl restart sshd
cd /
touch /etc/modprobe.d/block_usb.conf
echo "install usb-storage /bin/true"  >> /etc/modprobe.d/block_usb.conf
touch /etc/modprobe.d/blacklist-firewire.conf
echo "blacklist firewire-core" >> /etc/modprobe.d/blacklist-firewire.conf
touch  /etc/modprobe.d/block_usb.conf
echo "install usb-storage /bin/true" >> /etc/modprobe.d/block_usb.conf
cp -p /etc/bashrc /etc/bashrc-sec
cp -p /etc/csh.cshrc /etc/csh.cshrc-sec
cp -p /etc/csh.login /etc/csh.login-sec
cp -p /etc/profile /etc/profile-sec
mask=’027’
sed -e "s/002/$mask/" -e "s/027/$mask/" /etc/bashrc-sec > /etc/bashrc
sed -e "s/002/$mask/" -e "s/027/$mask/" /etc/csh.cshrc-sec > /etc/csh.cshrc
sed -e "s/002/$mask/" -e "s/027/$mask/" /etc/csh.login-sec > /etc/csh.login
mv /etc/sysctl.conf /etc/sysctl.conf.new
cd /etc/
wget https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/sysctl.conf
chmod 0600 /etc/sysctl.conf
sysctl -p
cd /
systemctl enable tmp.mount
cd /etc/modprobe.d/
mv /etc/modprobe.d/blacklist-networkprotocols.conf /etc/modprobe.d/blacklist-networkprotocols.conf.rnew
wget https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/blacklist-networkprotocols.conf
chmod 0600 /etc/modprobe.d/blacklist-networkprotocols.conf
yum install sysstat
systemctl start sysstat
systemctl enable sysstat
### install it
sudo yum install psacct
### then enable it and start it
sudo systemctl enable psacct.service
sudo systemctl start psacct.service
ac -p
cd /etc/audit/rules.d/
mv /etc/audit/rules.d/audit.rules /etc/audit/rules.d/audit.rules.new
https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/audit.rules
chmod 0600 /etc/audit/rules.d/audit.rules
sudo service auditd restart
sudo ln -s /opt/puppetlabs/bin/puppet /usr/bin/puppet
chmod 700 /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly 
chmod 600 /etc/crontab /etc/cron.deny /boot/grub2/grub.cfg
cat /etc/login.defs | awk '/UMASK/ { $2 = "027" } { print }' /etc/login.defs > /etc/login.defs.new
mv /etc/login.defs.new > /etc/login.defs
pkgchk -f -n -p /etc/login.defs
cat /etc/login.defs | awk '/PASS_MAX_DAYS/ { $2 = "60" } { print }' /etc/login.defs > /etc/login.defs.new
mv /etc/login.defs.new > /etc/login.defs
pkgchk -f -n -p /etc/login.defs
cat /etc/login.defs | awk '/PASS_MIN_LEN/ { $2 = "8" } { print }' /etc/login.defs > /etc/login.defs.new
mv /etc/login.defs.new > /etc/login.defs
pkgchk -f -n -p /etc/login.defs
cat /etc/login.defs | awk '/PASS_WARN_AGE/ { $2 = "7" } { print }' /etc/login.defs > /etc/login.defs.new
mv /etc/login.defs.new > /etc/login.defs
pkgchk -f -n -p /etc/login.defs
cat /etc/login.defs | awk '/SHA_CRYPT_MIN_ROUNDS/ { $2 = "65536" } { print }' /etc/login.defs > /etc/login.defs.new
mv /etc/login.defs.new > /etc/login.defs
pkgchk -f -n -p /etc/login.defs
cat /etc/selinux/config | awk '/SELINUX=/ { $1 = "SELINUX=permissive" } { print }' /etc/selinux/config > /etc/selinux/config.new
mv /etc/selinux/config.new /etc/selinux/config
pkgchk -f -n -p /etc/selinux/config
#init 6