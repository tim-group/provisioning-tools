require 'mcollective'
require 'provision'
require 'provision/workqueue'

module MCollective
  module Agent
    class Computenode < RPC::Agent

      def lockfile
        config.pluginconf["provision.lockfile"] || "/var/lock/provision.lock"
      end

      def provisioner
        Provision::Factory.new(:logger => logger)
      end

      def prepare_work_queue(specs, listener)
        work_queue = provisioner.work_queue(:worker_count=>1, :listener=>listener)
        work_queue.fill(specs)
        return work_queue
      end

      def provision(specs, listener)
        queue = prepare_work_queue(specs, listener)
        logger.info("Launching #{specs.size} nodes")
        queue.process()
        return listener.results
      end

      def clean(specs, listener)
        queue = prepare_work_queue(specs, listener)
        logger.info("Cleaning #{specs.size} nodes")
        queue.clean()
        return listener.results
      end

      def with_lock(&action)

        begin
          File.open(lockfile(), "w") do |f|
            f.flock(File::LOCK_EX)
            action.call
          end
        rescue Exception=>e
          logger.error(e)
          reply.data = {"error" => e.message, "backtrace" => e.backtrace}
          raise e
        end
      end

      def new_listener
        NoopListener.new(:logger => logger)
      end

      action "launch" do
        with_lock do
          specs = request[:specs]
          reply.data = provision(specs, new_listener())
        end
      end

      action "clean" do
        with_lock do
          specs = request[:specs]
          reply.data = clean(specs, new_listener())
        end
      end
    end
  end
end

