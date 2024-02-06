#!/bin/bash
#Paquetes
echo "Actualizando paquetes"
sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
yum update -y
yum install -y wget 
yum install java -y
subscription-manager register --username adminebc --password v6AonU3Iy8dF --auto-attach
yum install -y policycoreutils-python
#sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
#sudo dnf list docker-ce
#sudo dnf install docker-ce --nobest -y
sudo yum install ruby -y
cd /home/ec2-user
wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto
sudo service codedeploy-agent status
sudo service codedeploy-agent start
#sudo systemctl start docker
#sudo systemctl enable docker
#cd /etc/docker/
wget https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/daemon.json
chmod 640 /etc/docker/daemon.json
#mkdir /u01/docker_installation
#sudo systemctl daemon-reload
#systemctl restart docker	
cd /

#Instalando firewalld
echo "Instalando Firewalld"
yum install -y firewalld 
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --zone=public --add-port=22222/tcp
firewall-cmd --permanent --zone=public --add-port=443/tcp
firewall-cmd --permanent --zone=public --add-port=161/tcp
firewall-cmd --reload

#Habilitando tmp
echo "Montando tmp"
systemctl enable tmp.mount
#Banner Issue.net
mv /etc/issue.net /etc/issue.netrnew
cd /etc/
wget https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/issue.net
chmod 0644 /etc/issue.net
#Banner Issue
echo "Montando banner"
mv /etc/issue /etc/issue.rnew
cd /etc/
wget https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/issue
chmod 0644 /etc/issue 
#limits
echo "limits"
mv /etc/security/limits.conf /etc/security/limits.confrew
cd /etc/security/
wget https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/limits.conf
chmod 0644 /etc/security/limits.conf
#Profile
echo "profile"
mv /etc/profile /etc/profile.rew
cd /etc/
wget https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/profile
chmod 0644 /etc/profile
#login.defs
echo "defs_logins"
mv /etc/login.defs /etc/login.defs.rew
cd /etc/
wget https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/login.defs
chmod 0644 /etc/login.defs
#SSH
echo "Montando SSH"
mv /etc/ssh/sshd_config /etc/ssh/ssh_config.new
cd /etc/ssh/     
wget https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/sshd_config
chmod 0600 /etc/ssh/sshd_config
semanage port -a -t ssh_port_t -p tcp 22222
cd /
#Utilerias
echo "Utils"
touch /etc/modprobe.d/block_usb.conf
echo "install usb-storage /bin/true"  >> /etc/modprobe.d/block_usb.conf
touch /etc/modprobe.d/blacklist-firewire.conf
echo "blacklist firewire-core" >> /etc/modprobe.d/blacklist-firewire.conf
touch  /etc/modprobe.d/block_usb.conf
echo "install usb-storage /bin/true" >> /etc/modprobe.d/block_usb.conf

#UMASK
echo "Actualizando UMASK"
cp -p /etc/bashrc /etc/bashrc-sec
cp -p /etc/csh.cshrc /etc/csh.cshrc-sec
cp -p /etc/csh.login /etc/csh.login-sec
cp -p /etc/profile /etc/profile-sec
mask=’027’
sed -e "s/002/$mask/" -e "s/027/$mask/" /etc/bashrc-sec > /etc/bashrc
sed -e "s/002/$mask/" -e "s/027/$mask/" /etc/csh.cshrc-sec > /etc/csh.cshrc
sed -e "s/002/$mask/" -e "s/027/$mask/" /etc/csh.login-sec > /etc/csh.login

#sysctl
echo "Configuraciones de red sysctl"
mv /etc/sysctl.conf /etc/sysctl.conf.new
cd /etc/
wget https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/sysctl.conf
chmod 0644 /etc/sysctl.conf
sysctl -p
#Regreso a sistema
cd /
echo "Blacklist"
cd /etc/modprobe.d/
mv /etc/modprobe.d/blacklist-networkprotocols.conf /etc/modprobe.d/blacklist-networkprotocols.conf.rnew
wget https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/blacklist-networkprotocols.conf
chmod 0644 /etc/modprobe.d/blacklist-networkprotocols.conf
yum install -y sysstat
### install it
systemctl start sysstat
systemctl enable sysstat
### install it
sudo yum -y install psacct
### then enable it and start it
sudo systemctl enable psacct.service
sudo systemctl start psacct.service
ac -p
cd /etc/audit/rules.d/
mv /etc/audit/rules.d/audit.rules /etc/audit/rules.d/audit.rules.new
wget https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/audit.rules
chmod 0600 /etc/audit/rules.d/audit.rules
sudo service auditd restart
chmod 700 /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly 
chmod 600 /etc/crontab /etc/cron.deny /boot/grub2/grub.cfg
cat /etc/selinux/config | awk '/SELINUX=/ { $1 = "SELINUX=permissive" } { print }' /etc/selinux/config > /etc/selinux/config.new
mv -f /etc/selinux/config.new /etc/selinux/config
sudo systemctl enable tmp.mount
timedatectl set-timezone  America/Mexico_City
cd /etc/yum.repos.d/
wget https://raw.githubusercontent.com/Yamihatl-EBC/scrip_hardeding/dev/cisofy-lynis.repo
sudo yum install lynis -y
#init 6
