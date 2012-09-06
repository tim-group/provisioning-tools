module Provision::Image::Commands
  def cmd(cmd, log_file=console_log)
    log.debug("running command #{cmd}")
    if ! system("#{cmd}  >> #{log_file} 2>&1")
      raise Exception.new("command #{cmd} returned non-zero error code")
    end
  end

  def chroot(cmd)
    cmd("chroot #{spec[:temp_dir]} /bin/bash -c '#{cmd}'")
  end

  def apt_install(package)
    chroot("DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install #{package}")
  end

  class Continuation
      def initialize(target_object, block)
        raise "nil block given " unless block !=nil
        @block = block
        @target_object = target_object
      end

      def until(&condition)

        100.times {
          return if (@target_object.instance_eval(&condition) == true)
  	      @target_object.instance_eval(&@block)
          sleep(0.5)
       	}
        raise "timeout waiting for condition"
      end
  end

  def keep_doing(&block)
    return Continuation.new(self, block)
  end

  def wait_until(desc="", options= {:retry_attempts=>100}, &block)
    options[:retry_attempts].times {
      log.debug("waiting until: #{desc}")
      return if (block != nil and block.call() == true)
      sleep(0.4)
    }
    raise "timeout waiting for condition"
  end

end
