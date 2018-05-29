metadata    :name        => "computenode",
            :description => "",
            :author      => "",
            :license     => "",
            :version     => "",
            :url         => "",
            :timeout     => 10000

action "launch", :description => "" do
    display :always
end

action "clean", :description => "" do
    display :always
end

action "allocate_ips", :description => "" do
    display :always
end

action "free_ips", :description => "" do
    display :always
end

action "add_cnames", :description => "" do
    display :always
end

action "remove_cnames", :description => "" do
    display :always
end

action "check_definition", :description => "" do
    display :always
end

action "enable_live_migration", :description => "" do
    display :always
    input :other_host,
          :prompt      => "Other Host",
          :description => "The host being migrated from/to",
          :type        => :string,
          :validation  => '^[a-zA-Z\-_.\d]+$',
          :optional    => false,
          :maxlength   => 128

    input :direction,
          :prompt      => "Direction",
          :description => "Direction of migration: either inbound or outbound",
          :type        => :list,
          :list        => ["inbound", "outbound"],
          :optional    => false
end

action "disable_live_migration", :description => "" do
    display :always
    input :other_host,
          :prompt      => "Other Host",
          :description => "The host being migrated from/to",
          :type        => :string,
          :validation  => '^[a-zA-Z\-_.\d]+$',
          :optional    => false,
          :maxlength   => 128

    input :direction,
          :prompt      => "Direction",
          :description => "Direction of migration: either inbound or outbound",
          :type        => :list,
          :list        => ["inbound", "outbound"],
          :optional    => false
end
