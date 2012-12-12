ifconfig br_mgmt up 192.168.5.1/24
ifconfig br_prod up 192.168.6.1/24

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
