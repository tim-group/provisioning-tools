require 'mcollective'

include MCollective::RPC

mc = rpcclient("computenode")
mc.identity_filter "pg-kvm-005.mgmt.pg.net.local"
#ldn-dev-rpearce.youdevise.com"
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
      :prod => 'dev-tfundsproxy-001-grichards.pg.net.local',
      :mgmt => 'dev-tfundsproxy-001-grichards.mgmt.pg.net.local',
    },
    :cnames => {
      :prod => {
        'c.pg.net.local' => 'dev-tfundsproxy-001-grichards.pg.net.local',
      }
    },
    :ram => '2097152',
    :domain => 'pg.net.local',
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
      :prod => 'dev-tfundsproxy-002-grichards.pg.net.local',
      :mgmt => 'dev-tfundsproxy-002-grichards.mgmt.pg.net.local',
    },
    :cnames => {
      :prod => {
        'a.pg.net.local' => 'dev-tfundsproxy-001-grichards.pg.net.local',
        'b.pg.net.local' => 'dev-tfundsproxy-001-grichards.pg.net.local',
      }
    },
    :ram => '2097152',
    :domain => 'pg.net.local',
    :fabric => 'production'
  },
]
printrpc mc.allocate_ips(:specs => specs)
printrpc mc.add_cnames(:specs => specs)
printrpc mc.remove_cnames(:specs => specs)
printrpc mc.free_ips(:specs => specs)
#printrpc mc.free_cnames(:specs => specs)
#printrpc mc.allocate_ips(:specs => [
