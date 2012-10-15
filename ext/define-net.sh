virsh net-destroy mgmt
virsh net-undefine mgmt

virsh net-define "templates/mgmt.xml"
virsh net-start "mgmt"

virsh net-destroy back
virsh net-undefine back

virsh net-define "templates/back.xml"
virsh net-start "back"

virsh net-destroy middle
virsh net-undefine middle

virsh net-define "templates/middle.xml"
virsh net-start "middle"

virsh net-destroy front
virsh net-undefine front

virsh net-define "templates/front.xml"
virsh net-start "front"

