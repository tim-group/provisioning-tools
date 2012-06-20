module Provision::Commands
  def initialize(options)
    @console_log = options[:console_log]
    @dir = options[:dir]
  end

  def cmd(cmd)
    print "#{cmd}\n"
    if ! system("#{cmd}  >> console.log 2>&1")
      raise "command #{cmd} returned non-zero error code"
    end
  end

  def cmd_ignore(cmd)
    print "#{cmd}\n"
    
    system("#{cmd}  >> console_log 2>&1")
  end

  def chroot(dir, cmd)
    cmd("chroot #{dir} /bin/bash -c '#{cmd}'")
  end

  def chroot_ignore(dir, cmd)
    cmd_ignore("chroot #{dir} /bin/bash -c '#{cmd}'")
  end

  
  def cat(file, content)
    open(file, 'w') { |f|
      f.puts(content)
    }
  end

  def install(package)
    chroot("DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install #{package}")
  end

  def hostname(hostname)
  end
end

include Provision::Commands
