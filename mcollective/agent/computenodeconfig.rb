module MCollective
  module Agent
    class Computenodeconfig<RPC::Agent
      action "get" do
        reply[:response] = get(request)
      end
      def get(request)
        require 'rubygems'
        require 'yaml'
        key = request[:key] || false
        reply.fail! "Key is required" unless key

        config = YAML.load_file('/etc/provision/config.yaml')
        reply[:response] = config[key].inspect
      end
    end
  end
end
