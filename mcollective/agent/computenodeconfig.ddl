metadata :name        => "Compute node config",
         :description => "Inspect a section of the compute node config",
         :author      => "Infrastructure",
         :license     => "MIT",
         :version     => "1.0",
         :url         => "http://www.timgroup.com",
         :timeout     => 10800

action "get", :description => "Get configuration" do
        display :always

        input :key,
              :prompt      => "key",
              :description => "Key from the config yaml",
              :type        => :string,
              :validation  => :shellsafe,
              :optional    => false,
              :maxlength   => 90

end
