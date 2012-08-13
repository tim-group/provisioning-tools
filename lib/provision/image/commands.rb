module Provision::Image::Commands
  def initialize(options)
  end

  def console_log()
    return @console_log || "console.log"
  end

  def cmd(cmd)
    log.debug("running command #{cmd}")
    if ! system("#{cmd}  >> #{console_log} 2>&1")
      raise Exception.new("command #{cmd} returned non-zero error code")
    end
     `udevadm settle`
  end

  def chroot(cmd)
    cmd("chroot #{temp_dir} /bin/bash -c '#{cmd}'")
  end

  def apt_install(package)
    chroot("DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install #{package}")
  end

  class Continuation
      def initialize(block)
       @block = block
      end 
      def until(&condition)
        100.times {
	  @block.call()
          return if (condition.call() == true)
        }
      end
  end
 
  def keep_doing(&block)
    return Continuation.new(block)
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
