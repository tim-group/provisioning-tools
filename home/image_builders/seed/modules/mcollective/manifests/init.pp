class mcollective($broker) {
  include mcollective::install
  class { 'mcollective::config':
    broker     => $broker;
  }
  include mcollective::service
}

