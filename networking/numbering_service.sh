dnsmasq -s dev.net.local --strict-order --bind-interfaces --pid-file=/var/run/dnsmasq-mgmt.pid --except-interface lo --interface br_mgmt --listen-address 192.168.5.1 --dhcp-range 192.168.5.1,static --read-ethers --dhcp-no-override

dnsmasq -s dev.net.local --strict-order --bind-interfaces --pid-file=/var/run/dnsmasq-prod.pid --except-interface lo --interface br_prod --listen-address 192.168.6.1 --dhcp-range 192.168.6.100,192.168.6.254 --dhcp-lease-max=155 --dhcp-no-override --dhcp-leasefile=/var/cache/dnsmasq-prod.lease
