virsh net-destroy provnat
virsh net-undefine provnat

virsh net-define "templates/nat.xml"
virsh net-start "provnat"


