metadata    :name        => "Nuke Puppet Certificates",
            :description => "Agent to remove puppet certificates from a puppet client",
            :author      => "TIM Group",
            :license     => "MIT",
            :version     => "1",
            :url         => "http://www.timgroup.com",
            :timeout     => 15

action "clean", :description => "Clean the puppet certificates from a host" do
    output :status,
           :description => "Status of the removal",
           :display_as  => "Status"
end
