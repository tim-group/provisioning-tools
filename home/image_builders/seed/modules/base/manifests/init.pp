class base {
  if $::lsbdistcodename == 'lucid' or $::lsbdistcodename == 'precise' {
    include serial::grub
  }
  serial::console{ 'ttyS0':
    serial_port => 'ttyS0',
  }
}

