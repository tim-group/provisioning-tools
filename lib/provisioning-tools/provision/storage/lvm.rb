require 'provisioning-tools/provision/storage/local'

class Provision::Storage::LVM < Provision::Storage
  include Provision::Storage::Local

  def initialize(options)
    fail "LVM storage requires a volume group as an option, named vg" if options[:vg].nil?
    super(options)
  end

  def create(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    size = mount_point_obj.config[:size]
    if File.exists?("#{device(underscore_name)}")
      fail "Logical volume #{underscore_name} already exists in volume group #{@options[:vg]}"
    end
    run_task(name, "create #{underscore_name}",                :task => lambda do
      cmd "lvcreate -n #{underscore_name} -L #{size} #{@options[:vg]}"
    end,
                                                               :cleanup => lambda do
                                                                 remove(name, mount_point_obj.name)
                                                               end)
  end

  def grow_filesystem(name, mount_point_obj)
    rebuild_partition(name, mount_point_obj)
    check_and_resize_filesystem(name, mount_point_obj)
  end

  def shrink_filesystem(name, mount_point_obj)
    check_and_resize_filesystem(name, mount_point_obj, :minimum)
    rebuild_partition(name, mount_point_obj, :minimum)
    underscore_name = underscore_name(name, mount_point_obj.name)
    newsize = cmd("parted -sm #{device(underscore_name)} print | grep -e '^1:' | awk -F ':' '{ print $3 }'")

    run_task(name, "shrink lvm #{underscore_name}",                :task => lambda do
      cmd "lvreduce -f -L #{newsize} #{device(underscore_name)}"
    end)
  end

  def device(underscore_name)
    "/dev/#{@options[:vg]}/#{underscore_name}"
  end

  def remove(name, mount_point)
    underscore_name = underscore_name(name, mount_point)
    exception = nil
    100.times do |i|
      begin
        output = cmd "lvremove -f #{device(underscore_name)}" if File.exists?(device(underscore_name))
      rescue Exception => e
        exception = e if i >= 99
      end
      return output unless File.exists?(device(underscore_name))
    end
    if exception.nil?
      fail "Tried to lvremove but failed 100 times and didn't raise an exception!?"
    else
      fail exception
    end
  end

  def partition_name(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    vm_partition_name = cmd "kpartx -l #{device(underscore_name)} | grep -v 'loop deleted : /dev/loop' | " \
      "awk '{ print $1 }' | tail -1"
    fail "unable to work out vm_partition_name" if vm_partition_name.nil?
    vm_partition_name
  end
end
