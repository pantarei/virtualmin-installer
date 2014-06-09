#!/bin/bash

# Wrapper for Virtualmin installer.

# Ensure all APT source enabled.
sed -i 's/^#\s*deb/deb/g' /etc/apt/sources.list

# Install Virtualmin with GPL installation script.
export set VIRTUALMIN_NONINTERACTIVE=1
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

aptitude -y install apache2 apache2-doc apache2-mpm-prefork apache2-suexec-custom awstats bind9 clamav clamav-base clamav-daemon clamav-docs clamav-freshclam clamav-testfiles dovecot-common dovecot-imapd dovecot-pop3d iptables libapache2-mod-fcgid libapache2-mod-php5 libapache2-mod-ruby libapache2-svn libcrypt-ssleay-perl libdbd-mysql-perl libdbd-pg-perl libfcgi-dev libgd2-xpm libnet-ssleay-perl libpg-perl libsasl2-2 libsasl2-modules libxml-simple-perl mailman mysql-client mysql-common mysql-server openssl php-pear php5 php5-cgi php5-mysql postfix postfix-pcre postgresql postgresql-client procmail proftpd-basic python quota ri ruby sasl2-bin spamassassin spamc subversion unzip webalizer zip

aptitude -y install virtualmin-base usermin-virtual-server-mobile virtualmin-base webmin-virtual-server-mobile webmin-virtualmin-dav webmin-virtualmin-svn

# Post-configure after initial installation.
aptitude -y install bmon colordiff ffmpeg git htop libapache2-mod-rpaf libssh2-php lvm2 memcached mlocate nmap ntp openssh-server pbzip2 php-apc php-codesniffer php5-curl php5-ffmpeg php5-gd php5-gmp php5-imap php5-intl php5-mcrypt php5-memcache php5-pgsql php5-snmp php5-sqlite php5-tidy php5-xdebug php5-xmlrpc phpmyadmin pwgen resolvconf rsync varnish vim

# Some recommended tweak on Virtualmin especially for Drupal virtual hosting.
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
sed -i '1i export PATH="$HOME/.composer/vendor/bin:$PATH"' $HOME/.bashrc
composer global require drush/drush:6.*

a2enmod expires

echo "FileETag none" > /etc/apache2/conf.d/fileetag

cat > /etc/php5/conf.d/apc.ini <<-EOF
apc.gc_ttl=3600
apc.max_file_size=8M
apc.mmap_file_mask=/tmp/apc.XXXXXX
apc.rfc1867=1
apc.rfc1867_ttl=600
apc.shm_size=256M
apc.ttl=600
apc.user_ttl=600
extension=apc.so
EOF

cd /etc/php5/
find . -type f -name php.ini | while read line;
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

cat > /etc/apache2/mods-enabled/fcgid.conf <<-EOF
<IfModule mod_fcgid.c>
AddHandler fcgid-script .fcgi
FcgidConnectTimeout 30
FcgidMaxProcesses 256
FcgidMaxProcessesPerClass 8
FcgidProcessLifeTime 300
</IfModule>
EOF

/etc/init.d/apache2 restart
