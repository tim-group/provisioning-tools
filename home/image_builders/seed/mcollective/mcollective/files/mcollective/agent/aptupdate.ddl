metadata    :name        => "APT Update",
            :description => "Agent To Update git checkouts on apt repositories",
            :author      => "Infrastructure",
            :license     => "GPLv2",
            :version     => "1.0",
            :url         => "http://timgroup.com",
            :timeout     => 300

action "update", :description => "Update apt repository" do
  display :always

  output :output,
    :description => "Status of the git pull",
    :display_as  => "Status"
end
