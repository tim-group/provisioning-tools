require 'provisioning-tools/provision/storage/local'
require 'provisioning-tools/provision/storage/tasks'

class Provision::Storage::LVM < Provision::Storage
  include Provision::Storage::Local
  include Provision::Storage::Tasks

  def initialize(options)
    fail "LVM storage requires a volume group as an option, named vg" if options[:vg].nil?
    super(options)
  end

  def create(name, mount_point_obj)
    size = host_lv_size(mount_point_obj)

    guest_vg_name = guest_vg_name(name, mount_point_obj)
    host_lv_name = guest_vg_name

    create_lvm_lv_task(name, host_lv_name, @options[:vg], size)

    return unless create_lvm?(mount_point_obj)

    host_device = host_device(name, mount_point_obj)
    guest_lv_name = guest_lv_name(mount_point_obj)

    create_partition_task(name, host_device, 'ext2', true)
    create_partition_device_nodes_task(name, host_device)

    host_device_partition = host_device_partition(name, mount_point_obj)

    initialise_vg_in_guest_lvm_task(name, host_device_partition, guest_vg_name)
    create_lvm_lv_task(name, guest_lv_name, guest_vg_name, mount_point_obj.config[:size], false)
  end

  def diff_against_actual(name, specified_mp_objs)
    actual = Hash[cmd("lvs --noheadings --nosuffix --separator , --units k --options lv_name,vg_name,lv_size", true).
                  split("\n").
                  map(&:strip).
                  select { |line| line.start_with?(name) }.
                  map { |line| line.split(',') }.
                  select { |cols| cols[1] == @options[:vg] }.
                  map { |cols| [cols[0], :actual_size => cols[2].to_f] }]

    specified = Hash[specified_mp_objs.map do |mount_point_obj|
      lv_name = host_lv_name(name, mount_point_obj)
      lv_size = host_lv_size(mount_point_obj).chomp('G').to_f * 1024 * 1024
      [lv_name, :spec_size => lv_size]
    end]

    specified.
      merge(actual) { |_, s, a| s.merge(a) }.
      reject { |_, size| size[:spec_size] == size[:actual_size] }.
      map { |vol, size| "#{vol} differs: expected size '#{size[:spec_size]}' (KiB), but actual size is '#{size[:actual_size]}' (KiB)" }
  end

  def archive(name, mount_point_obj, archive_datetime)
    lv_name = host_lv_name(name, mount_point_obj)
    vg_name = @options[:vg]
    max_len = 126 - vg_name.length
    archive_lv_name = "a+#{archive_datetime.to_i}.#{lv_name}".slice(0, max_len)
    rename_lvm_lv(lv_name, vg_name, archive_lv_name)
  end

  def grow_filesystem(name, mount_point_obj)
    fail("it's currently not possible to grow the filesystem within lvm that's within lvm") if create_lvm?(mount_point_obj)
    rebuild_partition(name, mount_point_obj)
    check_and_resize_filesystem(name, mount_point_obj)
  end

  def shrink_filesystem(name, mount_point_obj)
    fail("it's currently not possible to shrink the filesystem within lvm that's within lvm") if create_lvm?(mount_point_obj)
    check_and_resize_filesystem(name, mount_point_obj, :minimum)
    rebuild_partition(name, mount_point_obj, :minimum)
    underscore_name = underscore_name(name, mount_point_obj.name)
    newsize = cmd("parted -sm #{device(underscore_name)} print | grep -e '^1:' | awk -F ':' '{ print $3 }'")

    run_task(name, "shrink lvm #{underscore_name}", :task => lambda do
      cmd "lvreduce -f -L #{newsize} #{device(underscore_name)}"
    end)
  end

  def device(underscore_name)
    "/dev/#{@options[:vg]}/#{underscore_name}"
  end

  def remove(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    host_device = host_device(name, mount_point_obj)
    destroy_partition_table_and_metadata(host_device) if create_lvm?(mount_point_obj)

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
    the_device = device(underscore_name)
    vm_partition_name = cmd "kpartx -l #{the_device} | grep -v 'loop deleted : /dev/loop' | " \
      "awk '{ print $1 }' | tail -1"
    fail "unable to work out vm_partition_name" if vm_partition_name.nil?
    vm_partition_name
  end

  def cleanup_lvm_on_host(name, mount_point_obj)
    host_device = host_device(name, mount_point_obj)
    guest_vg_name = guest_vg_name(name, mount_point_obj)
    disable_lvm_vg_task(name, guest_vg_name)
    remove_partition_device_nodes_task(name, host_device)
  end

  # FIXME: this should probably be in private with the other similar methods
  # and we should provide a way for provision service to obtain the device name to use in the fstab
  def guest_device(name, mount_point_obj)
    "/dev/#{guest_vg_name(name, mount_point_obj)}/#{guest_lv_name(mount_point_obj)}"
  end

  private

  def host_lv_name(name, mount_point_obj)
    "#{name}#{underscorize(mount_point_obj.name)}"
  end

  def host_lv_size(mount_point_obj)
    size = mount_point_obj.config[:size]
    if create_lvm?(mount_point_obj)
      begin
        size = mount_point_obj.config[:prepare][:options][:guest_lvm_pv_size]
      rescue
        size = false
      end
    end
    fail("prepare options guest_lvm_pv_size must be set to create lvm within the VM storage") unless size
    size
  end

  def guest_vg_name(name, mount_point_obj)
    host_lv_name(name, mount_point_obj)
  end

  def guest_lv_name(mount_point_obj)
    "#{underscorize(mount_point_obj.name)}"
  end

  def host_device(name, mount_point_obj)
    "/dev/#{@options[:vg]}/#{host_lv_name(name, mount_point_obj)}"
  end

  def host_device_partition(name, mount_point_obj)
    device_partition(name, mount_point_obj, host_device(name, mount_point_obj))
  end

  def device_partition(_name, _mount_point_obj, device)
    output = kpartxl(device)

    fail("cannot work out partition identifier for device #{device} from kpartxl output '#{output}',"\
         "it should only output 1 line") unless output.split("\n").length == 1

    regex = /^(\S+)\s:\s\d+\s\d+\s#{Regexp.escape(device)}\s\d+$/
    fail("cannot work out partition identifier from kpartxl output '#{output}', does not match regex '#{regex}'") unless output =~ regex

    "/dev/mapper/#{Regexp.last_match(1)}"
  end
end
