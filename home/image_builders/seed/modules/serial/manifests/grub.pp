class serial::grub {
  file {
    '/etc/default/grub':
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/serial/etc/default/grub';

    '/etc/grub.d/00_header':
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/serial/etc/grub.d/00_header';

    '/usr/sbin/grub-mkconfig':
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/serial/usr/sbin/grub-mkconfig';
  }
}
