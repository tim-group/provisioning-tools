module Provision::Commands
  def initialize(options)
  end

  def cmd(cmd)
    Provision.log.debug("running command #{cmd}")
    if ! system("#{cmd}  >> console.log 2>&1")
      raise Exception.new("command #{cmd} returned non-zero error code")
    end
  end

  def chroot(cmd)
    cmd("chroot #{temp_dir} /bin/bash -c '#{cmd}'")
  end

  def apt_install(package)
    chroot("DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install #{package}")
  end

end
