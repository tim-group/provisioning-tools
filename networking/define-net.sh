ifconfig br_mgmt up 192.168.5.1/24
ifconfig br_prod up 192.168.6.1/24

# FIXME - Madness
#/sbin/iptables -t nat -I POSTROUTING -o br_front -j MASQUERADE
#/sbin/iptables -I FORWARD -i br_mgmt -o br_front -j ACCEPT
#/sbin/iptables -I FORWARD -i br_mgmt -o br_front -m state --state RELATED,ESTABLISHED -j ACCEPT
#/sbin/iptables -I FORWARD -o br_mgmt -i br_front -m state --state RELATED,ESTABLISHED -j ACCEPT

virsh net-destroy mgmt
virsh net-undefine mgmt

virsh net-define "networking/mgmt.xml"
virsh net-start "mgmt"

virsh net-destroy prod
virsh net-undefine prod

virsh net-define "networking/prod.xml"
virsh net-start "prod"

virsh net-destroy front
virsh net-undefine front

virsh net-define "networking/front.xml"
virsh net-start "front"
