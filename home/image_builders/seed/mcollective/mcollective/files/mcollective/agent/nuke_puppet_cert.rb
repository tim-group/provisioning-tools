module MCollective
  module Agent
    class Nuke_puppet_cert<RPC::Agent
      def clean_action
        reply[:status] = run('rm -r /var/lib/puppet/ssl/*', :chomp => true)
      end
    end
  end
end
