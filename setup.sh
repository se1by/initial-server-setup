#! /bin/bash
export PATH=/usr/sbin:$PATH

if [ $# -gt 0 ]; then
	NEW_HOSTNAME=$1
else
	read -r -p "Enter new hostname (n to skip): " NEW_HOSTNAME
fi
if [ "$NEW_HOSTNAME" != "n" ]; then
	hostnamectl set-hostname $NEW_HOSTNAME
fi

read -r -p "Enter your storagebox user(u123456 format): " BORG_USER
BORG_PASSPHRASE="a"
BORG_PASSPHRASE_REPEATED="b"
while [ "$BORG_PASSPHRASE" != "$BORG_PASSPHRASE_REPEATED" ]
do
	read -s -r -p "Enter borg passphrase: " BORG_PASSPHRASE
	echo ""
	read -s -r -p "Enter again: " BORG_PASSPHRASE_REPEATED
	echo ""
done

read -r -p "Enter last IP segment: " IP_SEGMENT
echo "Configuring network..."
cp interfaces /etc/network/interfaces
sed -i s/__IP_SEGMENT__/"$IP_SEGMENT"/g /etc/network/interfaces

echo "Configuring SSH..."
sed -i -E 's/^#? ?Port 22$/Port 2202/' /etc/ssh/sshd_config
sed -i -E 's/^#? ?PasswordAuthentication .*$/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i -E 's/^#? ?PermitRootLogin .*$/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i -E 's/^#? ?X11Forwarding .*$/X11Forwarding no/' /etc/ssh/sshd_config
sed -i -E 's/^AcceptEnv/#AcceptEnv/' /etc/ssh/sshd_config
if [[ -z $(grep "AllowUsers jonas" /etc/ssh/sshd_config) ]]; then
	echo "AllowUsers jonas" >> /etc/ssh/sshd_config
fi	

echo "Updating system..."
apt update -y && apt upgrade -y

echo "Installing commonly used tools..."
apt install -y unattended-upgrades vim htop zsh git tmux

echo "Activating unattended upgrades..."
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "Creating user..."
useradd -m -d /home/jonas -s $(which zsh) jonas
mkdir /home/jonas/.ssh
cp id_rsa.pub /home/jonas/.ssh/authorized_keys
chown -R jonas:jonas /home/jonas
chmod 700 /home/jonas/.ssh
chmod 600 /home/jonas/.ssh/*

echo "Setting up shells for root and jonas..."
cp zshrc /root/.zshrc
cp aliases.zsh /root/.aliases.zsh
cp zshrc /home/jonas/.zshrc
cp aliases.zsh /home/jonas/.aliases.zsh
chsh -s $(which zsh) root

echo "Setting up german keyboard layout..."
cp keyboard /etc/default/keyboard
setupcon

echo "Setting up borg backup..."
cp backup.sh /usr/local/bin/backup
sed -i s/BORG_PASSPHRASE=\"__REPLACE_ME__\"/BORG_PASSPHRASE=\"$BORG_PASSPHRASE\"/ /usr/local/bin/backup	
sed -i s/BORG_DIR=\"__REPLACE_ME__\"/BORG_DIR=\"$(hostname)\"/ /usr/local/bin/backup	
sed -i s/BORG_USER=\"__REPLACE_ME__\"/BORG_USER=\"$BORG_USER\"/ /usr/local/bin/backup	
crontab -l | grep "/usr/local/bin/backup" || crontab -l | { cat; echo "0 0 * * * /usr/local/bin/backup > /dev/null 2>&1"; } | crontab -
echo "Creating root ssh key for backups..."
ssh-keygen -b 2048 -t rsa -f /root/.ssh/id_rsa -q -N "" -C "jonas+$(hostname)@seibert.ninja"

echo ""
echo ".--------------------------."
echo "| Initial setup completed! |"
echo "'--------------------------'"
echo ""

echo "Append this public key to the storagebox authorized_keys file to enable backups:"
cat /root/.ssh/id_rsa.pub
echo ""
echo ""
echo "Restarting sshd & networking service, your terminal will most likely hang due to ip address change."
echo "You should be able to reconnect with 'ssh -p 2202 jonas@$(grep "address 2a" /etc/network/interfaces|awk '{print $2}')'"
systemctl restart sshd.service
systemctl restart networking.service
