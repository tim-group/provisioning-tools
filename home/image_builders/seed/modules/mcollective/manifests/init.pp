class mcollective($broker="dev-puppetmaster-001.dev.net.local") {
  include mcollective::install
  class { 'mcollective::config':
    broker     => $broker;
  }
  include mcollective::service
}

