dnsmasq \
--log-dhcp \
-s mgmt.dev.net.local \
--strict-order \
--bind-interfaces \
--pid-file=/var/run/dnsmasq.pid \
--except-interface lo \
--dhcp-no-override \
--log-queries \
-7 /etc/dnsmasq.d,.dpkg-dist,.dpkg-old,.dpkg-new
