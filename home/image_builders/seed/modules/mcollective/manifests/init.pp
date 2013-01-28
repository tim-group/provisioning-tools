class mcollective($broker="dev-puppetmaster-001.local.net.local") {
  include mcollective::install
  class { 'mcollective::config':
    broker     => $broker;
  }
  include mcollective::service
}

