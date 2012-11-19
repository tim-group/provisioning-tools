class mcollective::service {

  # Start it
  service { 'mcollective':
     ensure            => running,
     enable            => true,
     require           => Class['mcollective::plugins'];
  }

}

