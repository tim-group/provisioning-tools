class mcollective($collective, $broker="dev-puppetmaster-001.dev.net.local") {
  include mcollective::install
  class { 'mcollective::config':
    collective => $collective,
    broker     => $broker;
  }
  include mcollective::service
}

