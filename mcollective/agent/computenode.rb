require 'mcollective'

module MCollective
  module Agent
    class Computenode < RPC::Agent

      def prepare_work_queue(specs, listener)
        require 'provision'
        require 'provision/inventory'
        require 'provision/workqueue'
        work_queue = Provision.work_queue(:worker_count=>1, :listener=>listener)
        work_queue.fill(specs)
      end

      def with_lock(&action)
        File.open("/var/lock/provision.lock", "w") do |f|
          f.flock(File::LOCK_EX)
          action.call
        end
      end

      action "launch" do
        with_lock do
          specs = request[:specs]
          listener = NoopListener.new
          queue = prepare_work_queue(specs, listener)

          puts "Launching #{specs.size} nodes"
          reply.data = queue.process(specs)
          return listener.results
        end
      end

      action "clean" do
        with_lock do
          specs = request[:specs]
          listener = NoopListener.new
          queue = prepare_work_queue(specs, listener)

          puts "Cleaning #{specs.size} nodes"
          reply.data = queue.clean(specs)
          return listener.results
        end
      end
    end
  end
end
