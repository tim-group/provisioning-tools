virsh net-destroy mgmt
virsh net-undefine mgmt

virsh net-define "networking/mgmt.xml"
virsh net-start "mgmt"

virsh net-destroy prod
virsh net-undefine prod

virsh net-define "networking/prod.xml"
virsh net-start "prod"
