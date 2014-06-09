#!/bin/bash

# Wrapper for Virtualmin installer.

set -o xtrace

# Clone repo into temp folder.
TMPDIR=`mktemp -d`
cd $TMPDIR
git init
git remote add origin https://github.com/phpshift/virtualmin.git
git fetch origin
git checkout master

# Export some environment variables.
export VIRTUALMIN_NONINTERACTIVE=1
export DEBIAN_FRONTEND=noninteractive

# Ensure all APT source enabled.
sed -i 's/^#\s*deb/deb/g' /etc/apt/sources.list

# Install Virtualmin with GPL installation script.
sh <(curl -sL http://software.virtualmin.com/gpl/scripts/install.sh) --force --host `hostname -f`

# (Double check) Install Virtualmin manually.
aptitude -y install ubuntu-extras-keyring && \
    aptitude update && \
    aptitude -y full-upgrade && \
    tasksel install openssh-server && \
    tasksel install server && \
    tasksel install mail-server && \
    aptitude -y install usermin webmin && \
    aptitude update && aptitude -y full-upgrade && aptitude autoclean && aptitude clean

aptitude -y install apache2 apache2-doc apache2-suexec-custom awstats awstats bind9 clamav clamav-base clamav-daemon clamav-docs clamav-freshclam clamav-testfiles dovecot-common dovecot-imapd dovecot-pop3d iptables irb libapache2-mod-fcgid libapache2-mod-php5 libapache2-svn libcrypt-ssleay-perl libcrypt-ssleay-perl libdbd-mysql-perl libdbd-pg-perl libfcgi-dev libnet-ssleay-perl libpg-perl libsasl2-2 libsasl2-modules libxml-simple-perl mailman mysql-client mysql-common mysql-server openssl php-pear php5 php5-cgi php5-mysql postfix postfix-pcre postgresql postgresql-client procmail procmail-wrapper proftpd python quota rdoc ri ruby ruby sasl2-bin scponly spamassassin spamc subversion unzip usermin webalizer webmin zip

aptitude -y install virtualmin-base usermin-virtual-server-mobile virtualmin-base webmin-virtual-server-mobile webmin-virtualmin-dav webmin-virtualmin-svn

# Post-configure after initial installation.
aptitude -y install bmon colordiff fail2ban ffmpeg git htop libapache2-mod-rpaf libssh2-php logwatch lvm2 memcached mlocate mytop nmap ntp openssh-server pbzip2 php-apc php-codesniffer php5-curl php5-ffmpeg php5-gd php5-gmp php5-imap php5-intl php5-mcrypt php5-memcache php5-pgsql php5-snmp php5-sqlite php5-tidy php5-xdebug php5-xmlrpc phpmyadmin pwgen resolvconf rsync sshfs varnish vim

# Rsync all prepared template files.
rsync -av $TMPDIR/files/etc/ /etc

# Archive /etc/webmin with git for debug.
git init /etc/webmin
cd /etc/webmin && git add --all .
cd /etc/webmin && git commit -am 'Initial commit'

# Some recommended tweak on Virtualmin especially for Drupal virtual hosting.
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
sed -i '1i export PATH="$HOME/.composer/vendor/bin:$PATH"' $HOME/.bashrc

composer global require "drush/drush:6.*"
composer global require "phpunit/phpunit=4.1.*"

a2enmod expires

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

sed -i 's/^\(mysql_charset\)=.*$/\1=utf8/g' /etc/webmin/virtual-server/config
sed -i 's/^\(mysql_collate\)=.*$/\1=utf8_general_ci/g' /etc/webmin/virtual-server/config
sed -i 's/^\(mysql_db\)=.*$/\1=${USER}/g' /etc/webmin/virtual-server/config
sed -i 's/^\(mysql_suffix\)=.*$/\1=${USER}_/g' /etc/webmin/virtual-server/config

sed -i 's/^\(quota\)=.*$/\1=/g' /etc/webmin/virtual-server/plans/0
sed -i 's/^\(uquota\)=.*$/\1=/g' /etc/webmin/virtual-server/plans/0
sed -i 's/^\(domslimit\)=.*$/\1=/g' /etc/webmin/virtual-server/plans/0

sed -i 's/^\(mysql\)=.*$/\1=${USER}_${PREFIX}/g' /etc/webmin/virtual-server/templates/1
sed -i 's/^\(mysql_suffix\)=.*$/\1=${USER}_${PREFIX}_/g' /etc/webmin/virtual-server/templates/1

# Restart services.
/etc/init.d/apache2 restart
/etc/init.d/mysql restart
/etc/init.d/proftpd stop; /etc/init.d/proftpd start
/etc/init.d/mailman stop; /etc/init.d/mailman start
