module Provision::Image::Commands
  def initialize(options)
  end

  def cmd(cmd)
    Provision.log.debug("running command #{cmd}")
    if ! system("#{cmd}  >> console.log 2>&1")
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

  def wait_until(desc="", &block)    
    100.times {
      Provision.log.debug("waiting until: #{desc}")
      return if (block != nil and block.call() == true) 
      sleep(0.4)
    }
    raise "timeout waiting for condition"
  end
  
end
