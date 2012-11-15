virsh net-destroy mgmt
virsh net-undefine mgmt

virsh net-define "mgmt.xml"
virsh net-start "mgmt"

virsh net-destroy prod
virsh net-undefine prod

virsh net-define "prod.xml"
virsh net-start "prod"
