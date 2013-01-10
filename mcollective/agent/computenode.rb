require 'mcollective'
require 'provision'
require 'provision/inventory'
require 'provision/workqueue'

module MCollective
  module Agent
    class Computenode < RPC::Agent

      def prepare_work_queue(specs, listener)
        work_queue = Provision.work_queue(:worker_count=>1, :listener=>listener)
        work_queue.fill(specs)
        return work_queue
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
          queue.process()
          reply.data = listener.results
        end
      end

      action "clean" do
        with_lock do
          specs = request[:specs]
          listener = NoopListener.new
          queue = prepare_work_queue(specs, listener)

          puts "Cleaning #{specs.size} nodes"
          queue.clean()
          reply.data = listener.results
        end
      end
    end
  end
end
