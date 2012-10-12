virsh net-destroy provnat
virsh net-undefine provnat

virsh net-define "templates/nat.xml"
virsh net-start "provnat"

virsh net-destroy provnat2
virsh net-undefine provnat2

virsh net-define "templates/nat2.xml"
virsh net-start "provnat2"

virsh net-destroy provnat3
virsh net-undefine provnat3

virsh net-define "templates/nat3.xml"
virsh net-start "provnat3"


