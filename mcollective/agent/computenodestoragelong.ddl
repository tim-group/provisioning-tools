metadata    :name        => "RPC agent for performing long running compute node storage operations",
            :description => "RPC agent for performing long running compute node storage operations",
            :author      => "Gary R",
            :url         => "http://timgroup.com",
            :license     => "MIT",
            :version     => "1.0",
            :timeout     => 999

action "copy", :description => "copies a machines storage to a specified destination" do
   display :always
     input :source,
           :prompt      => "Storage source in the format vm_name:storage_type:optional_mount_point",
           :description => "The storage source to be copied",
           :type        => :string,
           :validation  => '^[a-zA-Z\-_\d]+:[a-zA-Z\-_\d]+(:[a-zA-Z\-_\d\/]*)?$',
           :optional    => false,
           :maxlength   => 200

     input :transport,
           :prompt      => "Comma separated list of transports",
           :description => "A list of transports, comma separated, to move the storage to your required destination. Current transports: dd_from_source, dd_of, gzip, gunzip, ssh_cmd, end_ssh_cmd",
           :type        => :string,
           :validation  => '^([a-zA-Z_-]+)(,[a-zA-Z_-]+)*$',
           :optional    => false,
           :maxlength   => 200

     input :transport_options,
           :prompt      => "Comma separated list of transport options",
           :description => "A list of transport options, comma separated, to configure your transports. options are of the format transport_name__option_name:value. Note the double underscore between the transport name and the option name! Current transport options are: ssh_cmd__username, ssh_cmd__host, dd_of__path",
           :type        => :string,
           :validation  => '^([\w]+__[\w]+:[\w\-\.\/]+)(,[\w]+__[\w]+:[\w\-\.\/]+)*$',
           :optional    => false,
           :maxlength   => 400
end
