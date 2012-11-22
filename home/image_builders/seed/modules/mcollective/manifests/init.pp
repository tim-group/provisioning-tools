class mcollective($collective) {
  include mcollective::install
  class { 'mcollective::config':
    collective => $collective
  }
  include mcollective::service
}

