#!/bin/bash

set -o xtrace

# Update resolv.conf with "nameserver 127.0.0.1".
sed -i 's/^#\(prepend domain-name-servers\).*$/\1 127.0.0.1;/g' /etc/dhcp/dhclient.conf
/etc/init.d/networking restart
/etc/init.d/resolvconf restart
cat /etc/resolv.conf 

# Print the clean history command.
cat <<-EOF
# Command for clean history and logout current session.
rm -f \$HISTFILE && unset HISTFILE && exit
EOF
