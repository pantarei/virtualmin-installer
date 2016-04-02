#!/bin/bash

# Wrapper for Virtualmin installer.

# Enable xtrace for debug.
set -o xtrace

# Export some environment variables.
export VIRTUALMIN_NONINTERACTIVE=1
export DEBIAN_FRONTEND=noninteractive

# Define variables.
BRANCH="master"
PASSWD=`< /dev/urandom tr -dc A-Za-z0-9 | head -c8`
TMPDIR=`mktemp -d -t virtualmin-installer.XXXXXX`

# Update root password
echo "root:$PASSWD" | chpasswd

# Ensure all APT source and install required packages.
sed -i 's/^#\s*deb/deb/g' /etc/apt/sources.list
apt-get install aptitude dselect tasksel
apt-get update && aptitude -y full-upgrade && aptitude autoclean && aptitude clean
apt-get -y install coreutils curl git pwgen sed wget
dselect update
tasksel install openssh-server
tasksel install server
tasksel install mail-server

# Install Linux kernel extra modules and enable quota support.
apt-get -y install linux-generic-lts-xenial
modprobe quota_v1 quota_v2

# Install Virtualmin with GPL installation script.
echo "deb http://software.virtualmin.com/gpl/ubuntu/ virtualmin-trusty main" >> /etc/apt/sources.list
echo "deb http://software.virtualmin.com/gpl/ubuntu/ virtualmin-universal main" >> /etc/apt/sources.list
curl -sL http://software.virtualmin.com/lib/RPM-GPG-KEY-virtualmin | apt-key add
curl -sL http://software.virtualmin.com/lib/RPM-GPG-KEY-webmin | apt-key add
apt-get update
apt-get -y install virtualmin-base webmin-security-updates webmin-virtual-server webmin-virtual-server-theme webmin-virtualmin-awstats webmin-virtualmin-htpasswd webmin-virtualmin-mailman



# Clone repo into temp folder.
cd $TMPDIR
git init
git remote add origin https://github.com/phpshift/virtualmin-installer.git
git fetch origin
git checkout $BRANCH

# Post-configure after initial installation.
apt-get
-y
install
automysqlbackup
bmon
build-essential
colordiff
composer
fail2ban
ffmpeg
fonts-droid
fonts-noto
git
htop
libapache2-mod-rpaf
libssh2-php
logwatch
lvm2
memcached
mlocate
mytop
nmap
nodejs
ntp
openssh-server
pbzip2
php-apc
php-codesniffer
php5-curl
php5-gd
php5-gmp
php5-imap
php5-intl
php5-mcrypt
php5-memcache
php5-pgsql
php5-snmp
php5-sqlite
php5-tidy
php5-xdebug
php5-xmlrpc
phpmyadmin
pwgen
resolvconf
rsync
snmp-mibs-downloader
sshfs
usermin
usermin-virtual-server-mobile
varnish
vim
virtualmin-base
webmin
webmin-virtual-server-mobile
webmin-virtualmin-dav
webmin-virtualmin-svn

# Rsync all prepared template files.
rsync -av $TMPDIR/files/etc/ /etc

# Archive /etc/webmin with git for debug.
git init /etc/webmin
cd /etc/webmin && git add --all .
cd /etc/webmin && git commit -am 'Initial commit'

# Some recommended tweak on Virtualmin especially for Drupal virtual hosting.
sed -i '1i export PATH="$HOME/.composer/vendor/bin:$PATH"' $HOME/.bashrc
source $HOME/.bashrc

a2enmod expires
a2enconf etag

find /etc/php5 -type f -name php.ini | while read line;
do
    sed -i 's/^;*\(date\.timezone\) =.*$/\1 = "Asia\/Hong_Kong"/g' $line
    sed -i 's/^;*\(display_errors\) =.*$/\1 = Off/g' $line
    sed -i 's/^;*\(max_execution_time\) =.*$/\1 = 3600/g' $line
    sed -i 's/^;*\(max_input_time\) =.*$/\1 = 7200/g' $line
    sed -i 's/^;*\(memory_limit\) =.*$/\1 = 256M/g' $line
    sed -i 's/^;*\(post_max_size\) =.*$/\1 = 32M/g' $line
    sed -i 's/^;*\(short_open_tag\) =.*$/\1 = Off/g' $line
    sed -i 's/^;*\(upload_max_filesize\) =.*$/\1 = 32M/g' $line
done

newlist -q mailman admin@example.com $PASSWD

bash <(curl -sL https://raw.githubusercontent.com/pantarei/vundle-installer/master/install.sh)
bash <(curl -sL https://raw.githubusercontent.com/pantarei/composer-installer/master/install.sh)
bash <(curl -sL https://raw.githubusercontent.com/pantarei/npm-installer/master/install.sh)

# Additional webmin/virtualmin configuration.
cat >> /etc/webmin/virtual-server/config <<-EOF
bw_active=1
bw_disable=0
bw_enable=0
bw_mail_all=0
bw_step=1
defip=0.0.0.0
passwd_length=8
passwd_mode=1
EOF

virtualmin modify-plan --id 0 --no-quota --no-admin-quota --no-max-doms

virtualmin modify-template --id 0 --setting mysql --value '${USER}'
virtualmin modify-template --id 0 --setting mysql_charset --value 'utf8'
virtualmin modify-template --id 0 --setting mysql_collate --value 'utf8_general_ci'
virtualmin modify-template --id 0 --setting mysql_suffix --value '${USER}_'
virtualmin modify-template --id 0 --setting web_php_suexec --value 2

virtualmin modify-template --id 1 --setting mysql --value '${USER}_${PREFIX}'
virtualmin modify-template --id 1 --setting mysql_suffix --value '${USER}_${PREFIX}_'
virtualmin modify-template --id 1 --setting web_php_suexec --value 2

# Restart services.
for service in apache2 bind9 dovecot mailman memcached mysql postfix proftpd varnish
do
    for i in `seq 1 3`
    do
        /etc/init.d/$service stop
    done
    /etc/init.d/$service start
done

# Setup MySQL root password.
for i in `seq 1 10`
do
    /etc/init.d/mysql stop
    killall -9 mysqld
done

mysqld_safe --skip-grant-tables &
sleep 10

mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('$PASSWD') WHERE User = 'root';"
mysql -u root -e "FLUSH PRIVILEGES;"

cat >> /etc/webmin/mysql/config <<-EOF
pass=$PASSWD
EOF

cat > $HOME/.my.cnf <<-EOF
[client]
host     = localhost
user     = root
password = $PASSWD
socket   = /var/run/mysqld/mysqld.sock
EOF
chmod 600 $HOME/.my.cnf

for i in `seq 1 10`
do
    /etc/init.d/mysql stop
    killall -9 mysqld
done
/etc/init.d/mysql restart

# Create example.com demo domain.
virtualmin create-domain --default-features --domain example.com --pass $PASSWD
virtualmin create-domain --default-features --domain sub.example.com --parent example.com
virtualmin create-domain --default-features --domain alias.example.com --alias example.com

mkdir -p /home/example/public_html
cd /home/example/public_html
echo "<?php phpinfo(); ?>" > phpinfo.php
bash <(curl -sL http://cgit.drupalcode.org/drustack/plain/drustack.sh) -f
drush -y site-install standard --db-url=mysql://example:$PASSWD@localhost/example --account-pass=$PASSWD
chown -Rf example:example /home/example/
