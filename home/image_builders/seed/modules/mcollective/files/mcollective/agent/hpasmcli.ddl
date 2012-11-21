metadata :name        => "HP ASM CLI",
         :description => "Agent to run the hpasmcli command on servers",
         :author      => "Infrastructure Team",
         :license     => "MIT",
         :version     => "1.0",
         :url         => "http://www.timgroup.com",
         :timeout     => 120

action "run", :description => "Runs the command and returns output" do
  input :cmd,
        :prompt      => "Command",
        :description => "The command to run",
        :type        => :string,
        :validation  => '.+',
        :optional    => false,
        :maxlength   => 30

  display :always

  output :response,
         :description => "The response returned",
         :display_as  => "Response"
end
