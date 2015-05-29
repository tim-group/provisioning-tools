require 'mcollective'
require 'provisioning-tools/provision'
require 'provisioning-tools/provision/workqueue'
require 'provisioning-tools/util/symbol_utils'

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
        work_queue = provisioner.work_queue(
          :worker_count => 1,
          :listener => listener)

        symbol_utils = ::Util::SymbolUtils.new
        specs = specs.map do |spec|
          symbol_utils.symbolize_keys(spec)
        end

        work_queue
      end

      def provision(specs, listener)
        logger.info("Launching #{specs.size} nodes")
        queue = prepare_work_queue(specs, listener)
        queue.launch_all(specs)
        listener.results
      end

      def clean(specs, listener)
        queue = prepare_work_queue(specs, listener)
        logger.info("Cleaning #{specs.size} nodes")
        queue.destroy_all(specs)
        listener.results
      end

      def allocate_ips(specs, listener)
        queue = prepare_work_queue(specs, listener)
        logger.info("Allocating IP addresses for #{specs.size} nodes")
        queue.allocate_ip_all(specs)
        listener.results
      end

      def free_ips(specs, listener)
        queue = prepare_work_queue(specs, listener)
        logger.info("Freeing IP addresses for #{specs.size} nodes")
        queue.free_ip_all(specs)
        listener.results
      end

      def add_cnames(specs, listener)
        queue = prepare_work_queue(specs, listener)
        logger.info("Adding CNAME's #{specs}")
        queue.add_cnames(specs)
        listener.results
      end

      def remove_cnames(specs, listener)
        queue = prepare_work_queue(specs, listener)
        logger.info("Removing CNAME's for #{specs.size} nodes")
        queue.remove_cnames(specs)
        listener.results
      end

      def with_lock(&action)
        File.open(lockfile, "w") do |f|
          f.flock(File::LOCK_EX)
          action.call
        end
      rescue Exception => e
        logger.error(e)
        reply.data = { "error" => e.message, "backtrace" => e.backtrace }
        raise e
      end

      def new_listener
        NoopListener.new(:logger => logger)
      end

      action "launch" do
        with_lock do
          specs = request[:specs]
          reply.data = provision(specs, new_listener)
        end
      end

      action "clean" do
        with_lock do
          specs = request[:specs]
          reply.data = clean(specs, new_listener)
        end
      end

      action "allocate_ips" do
        specs = request[:specs]
        reply.data = allocate_ips(specs, new_listener)
      end

      action "free_ips" do
        specs = request[:specs]
        reply.data = free_ips(specs, new_listener)
      end

      action "add_cnames" do
        specs = request[:specs]
        reply.data = add_cnames(specs, new_listener)
      end

      action "remove_cnames" do
        specs = request[:specs]
        reply.data = remove_cnames(specs, new_listener)
      end
    end
  end
end
