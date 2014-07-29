require 'util/symbol_utils'

module Provision::Image::Commands

  def cmd(cmd)
    log.debug("running command #{cmd}")

    output = ""
    IO.popen("#{cmd} 2>&1", "w+") do |pipe|
      # open in write mode and then close the output stream so that the subprocess doesn't capture our STDIN
      pipe.close_write
      pipe.each_line do |line|
        log.debug("> " + line.chomp)
        output = output + line.chomp
      end
    end

    exit_status = $?
    if exit_status != 0
      raise "command #{cmd} returned non-zero error code #{exit_status}, output: #{output}"
    end
    return output
  end

  def chroot(cmd)
    cmd("chroot #{spec[:temp_dir]} /bin/bash -c '#{cmd}'")
  end

  def apt_install(package)
    chroot("DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install #{package}")
  end

  def apt_download(package)
    chroot("DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes -d install #{package}")
  end

  def apt_remove(package)
    chroot("DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes remove #{package}")
  end

  def symbol_utils
    return Util::SymbolUtils.new
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

