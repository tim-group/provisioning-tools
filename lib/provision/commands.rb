module Provision::Commands
  def initialize(options)
    @console_log = options[:console_log]
    @dir = options[:dir]
  end

  def cmd(cmd)
    if ! system("#{cmd}  >> console.log 2>&1")
      raise "command returned non-zero error code"
    end
  end

  def cmd_ignore(cmd)
    system("#{command}  >> #{@console_log} 2>&1")
  end

  def chroot(cmd)
    cmd("chroot #{@dir} /bin/bash -c '#{command}'")
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
     puts "HOSTNAME #{hostname}"
  end
end

include Provision::Commands
