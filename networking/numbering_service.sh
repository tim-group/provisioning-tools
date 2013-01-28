dnsmasq \
--log-dhcp \
-s mgmt.local.net.local \
--strict-order \
--bind-interfaces \
--pid-file=/var/run/dnsmasq.pid \
--except-interface lo \
--dhcp-no-override \
--log-queries
