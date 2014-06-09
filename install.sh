#!/bin/bash

# Wrapper for Virtualmin installer.

set -o xtrace

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

# Some recommended tweak on Virtualmin especially for Drupal virtual hosting.
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
sed -i '1i export PATH="$HOME/.composer/vendor/bin:$PATH"' $HOME/.bashrc

composer global require "drush/drush:6.*"
composer global require "phpunit/phpunit=4.1.*"

a2enmod expires

cat > /etc/apache2/conf.d/etag <<-EOF
FileETag None
<ifModule mod_headers.c>
    Header unset ETag
</ifModule>
EOF

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

cat > /etc/apache2/mods-enabled/fcgid.conf <<-EOF
<IfModule mod_fcgid.c>
    AddHandler fcgid-script .fcgi
    FcgidConnectTimeout 30
    FcgidMaxProcesses 256
    FcgidMaxProcessesPerClass 8
    FcgidProcessLifeTime 300
</IfModule>
EOF

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

/etc/init.d/apache2 restart

# Additional webmin/virtualmin configuration.
cat > /etc/webmin/virtual-server/custom-shells <<-EOF
owner= desc=Email only id=nologin      default=1       mailbox=1       shell=/dev/null avail=1
owner= desc=Email and FTP      id=ftp  default=        mailbox=1       shell=/bin/false        avail=1
owner= desc=Email and SCP      id=nologin      default=        mailbox=1       shell=/usr/bin/scponly  avail=1
owner=1        desc=Email only id=nologin      default=        mailbox=        shell=/dev/null avail=
owner=1        desc=Email and FTP      id=ftp  default=        mailbox=        shell=/bin/false        avail=
owner=1        desc=Email, FTP and SSH id=ssh  default=        mailbox=        shell=/usr/bin/scponly  avail=
owner=1        desc=Email, FTP and SSH id=ssh  default=1       mailbox=        shell=/bin/bash avail=1
owner=1        desc=Email, FTP and SSH id=ssh  default=        mailbox=        shell=/bin/sh   avail=1
owner=1        desc=Email, FTP and SSH id=ssh  default=        mailbox=        shell=/usr/bin/screen   avail=
owner=1        desc=Email, FTP and SSH id=ssh  default=        mailbox=        shell=/bin/dash avail=
owner=1        desc=Email, FTP and SSH id=ssh  default=        mailbox=        shell=/usr/bin/tmux     avail=
owner=1        desc=Email, FTP and SSH id=ssh  default=        mailbox=        shell=/bin/rbash        avail=
EOF

cat > /etc/webmin/virtual-server/templates/1 <<-EOF
mysql_suffix=${USER}_${PREFIX}_
mysql=${USER}_${PREFIX}
EOF

sed -i 's/^\(mysql_charset\)=.*$/\1=utf8/g' /etc/webmin/virtual-server/config
sed -i 's/^\(mysql_collate\)=.*$/\1=utf8_general_ci/g' /etc/webmin/virtual-server/config
sed -i 's/^\(mysql_db\)=.*$/\1=${USER}/g' /etc/webmin/virtual-server/config
sed -i 's/^\(mysql_suffix\)=.*$/\1=${USER}_/g' /etc/webmin/virtual-server/config

sed -i 's/^\(quota\)=.*$/\1=/g' /etc/webmin/virtual-server/plans/0
sed -i 's/^\(uquota\)=.*$/\1=/g' /etc/webmin/virtual-server/plans/0
sed -i 's/^\(domslimit\)=.*$/\1=/g' /etc/webmin/virtual-server/plans/0
