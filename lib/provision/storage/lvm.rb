require 'provision/storage/local'

class Provision::Storage::LVM < Provision::Storage
  include Provision::Storage::Local

  def initialize(options)
    raise "LVM storage requires a volume group as an option, named vg" if options[:vg].nil?
    super(options)
  end

  def create(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    size = mount_point_obj.config[:size]
    if File.exists?("#{device(underscore_name)}")
      raise "Logical volume #{underscore_name} already exists in volume group #{@options[:vg]}"
    end
    run_task(name, "create #{underscore_name}", {
      :task => lambda {
        cmd "lvcreate -n #{underscore_name} -L #{size} #{@options[:vg]}"
      },
      :cleanup => lambda {
        remove(name, mount_point_obj.name)
      }
    })
  end

  def grow_filesystem(name, mount_point_obj)
    rebuild_partition(name, mount_point_obj)
    check_and_resize_filesystem(name, mount_point_obj)
  end

  def device(underscore_name)
    return "/dev/#{@options[:vg]}/#{underscore_name}"
  end

  def remove(name, mount_point)
    underscore_name = underscore_name(name, mount_point)
    cmd "lvremove -f #{device(underscore_name)}" if File.exists?(device(underscore_name))
  end

  def partition_name(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    vm_partition_name = cmd "kpartx -l #{device(underscore_name)} | grep -v 'loop deleted : /dev/loop' | awk '{ print $1 }' | tail -1"
    raise "unable to work out vm_partition_name" if vm_partition_name.nil?
    return vm_partition_name
  end

end