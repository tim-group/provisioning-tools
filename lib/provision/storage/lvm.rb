require 'provision/storage/local'

class Provision::Storage::LVM < Provision::Storage
  include Provision::Storage::Local

  def initialize(options)
    raise "LVM storage requires a volume group as an option, named vg" if options[:vg].nil?
    super(options)
  end

  def create(name, mount_point, size)
    underscore_name = underscore_name(name, mount_point)
    if File.exists?("#{device(underscore_name)}")
      raise "Logical volume #{underscore_name} already exists in volume group #{@options[:vg]}"
    end
    run_task(name, {
      :task => lambda {
        cmd "lvcreate -n #{underscore_name} -L #{size} #{@options[:vg]}"
      },
      :cleanup => lambda {
        remove(underscore_name)
      }
    })
  end

  def grow_filesystem(name, mount_point, size, options_hash={})
    rebuild_partition(name, mount_point, options_hash)
    check_and_resize_filesystem(name, mount_point)
  end

  def device(underscore_name)
    return "/dev/#{@options[:vg]}/#{underscore_name}"
  end

  def remove(underscore_name)
    cmd "lvremove -f #{device(underscore_name)}"
  end
end
