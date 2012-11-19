class mcollective {
  include mcollective::install
  include mcollective::config
  include mcollective::plugins
  include mcollective::service
}

