metadata    :name        => "nagsrv",
            :description => "Manipulate nagios servers using the ruby-nagios library",
            :author      => "crazed",
            :license     => "Unknown",
            :url         => "http://github.com/crazed/mcollective-nagsrv",
            :version     => "0.1",
            :timeout     => 120

action "stats", :description => "return basic stats about services and hosts" do
  output :stats,
         :description => "Stats gathered from nagios",
         :display_as => "Stats"
end

