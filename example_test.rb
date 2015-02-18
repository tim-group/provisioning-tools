require 'mcollective'

include MCollective::RPC

mc = rpcclient("computenode")
mc.identity_filter "pg-kvm-005.mgmt.pg.net.local"
domain = "pg.net.local"
mc.verbose = true
specs = [
  {
    :networks => [
      :mgmt,
      :prod
    ],
    :hostname => 'dev-tfundsproxy-001-grichards',
    :group => 'dev-tfundsproxy',
    :qualified_hostnames => {
      :prod => "dev-tfundsproxy-001-grichards.#{domain}",
      :mgmt => "dev-tfundsproxy-001-grichards.mgmt.#{domain}"
    },
    :cnames => {
      :prod => {
        "c" => "dev-tfundsproxy-001-grichards.#{domain}"
      }
    },
    :ram => '2097152',
    :domain => "#{domain}",
    :fabric => 'production'
  },
  {
    :networks => [
      :mgmt,
      :prod
    ],
    :hostname => 'dev-tfundsproxy-002-grichards',
    :group => 'dev-tfundsproxy',
    :qualified_hostnames => {
      :prod => "dev-tfundsproxy-002-grichards.#{domain}",
      :mgmt => "dev-tfundsproxy-002-grichards.mgmt.#{domain}"
    },
    :cnames => {
      :prod => {
        "a" => "dev-tfundsproxy-001-grichards.#{domain}",
        "b" => "dev-tfundsproxy-001-grichards.#{domain}"
      }
    },
    :ram => '2097152',
    :domain => "#{domain}",
    :fabric => 'production'
  }
]
printrpc mc.allocate_ips(:specs => specs)
printrpc mc.add_cnames(:specs => specs)
printrpc mc.remove_cnames(:specs => specs)
printrpc mc.free_ips(:specs => specs)
