class apt_cacher_ng {
  include apt_cacher_ng::install
  include apt_cacher_ng::service
  include apt_cacher_ng::config
}
