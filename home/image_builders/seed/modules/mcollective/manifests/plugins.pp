class mcollective::plugins {

  File {
    require => Class['mcollective::config'],
  }


  # Add plugins
  file {
  '/usr/share/mcollective/plugins/mcollective':
    ensure  => directory,
    source  => 'puppet:///modules/mcollective/mcollective',
    recurse => true;
  }
}

