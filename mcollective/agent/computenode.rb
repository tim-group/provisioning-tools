require 'mcollective'

module MCollective
  module Agent
    class Computenode < RPC::Agent

      def provision(specs)
        require 'provision'
        require 'provision/inventory'
        require 'provision/workqueue'
        listener = NoopListener.new()
        work_queue = Provision.work_queue(:worker_count=>1, :listener=>listener)
        work_queue.fill(specs)
        work_queue.process()
        return listener.results()
      end

      action "launch" do
        File.open("/var/lock/provision.lock", "w") do |f|
          f.flock(File::LOCK_EX)
          specs = request[:specs]
          puts "Building #{specs.size} nodes"
          reply.data = provision(specs)
        end
      end
    end
  end
end
