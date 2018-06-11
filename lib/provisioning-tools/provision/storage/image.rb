require 'provisioning-tools/provision/storage/local'

class Provision::Storage::Image < Provision::Storage
  include Provision::Storage::Local

  def initialize(options)
    fail "Image storage requires a path as an option, named path" if options[:image_path].nil?
    @image_path = options[:image_path]
    super(options)
  end

  def create(name, mount_point_obj)
    fail("it's currently not possible to create lvm that's within an image") if create_lvm?(mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    size = mount_point_obj.config[:size]
    fail "Image file #{device(underscore_name)} already exists" if File.exist?("#{device(underscore_name)}")
    run_task(name, "create #{underscore_name}",
             :task => lambda { cmd "qemu-img create #{device(underscore_name)} #{size}" },
             :cleanup => lambda { remove(name, mount_point_obj) })
  end

  def diff_against_actual(name, specified_mp_objs)
    actual = Hash[Dir[device("#{name}_*")].map { |f| [f, { :actual_size => File.size(f).to_f / 1024.0 }] }]
    specified = Hash[specified_mp_objs.map do |mp|
      [device(underscore_name(name, mp.name)), { :spec_size => kb_from_size_string(mp.config[:size]).to_f }]
    end]

    specified.
      merge(actual) { |_, s, a| s.merge(a) }.
      reject { |_, size| size[:spec_size] == size[:actual_size] }.
      map { |vol, size| "#{vol} differs: expected size '#{size[:spec_size]}', but actual size is '#{size[:actual_size]}'" }
  end

  def grow_filesystem(name, mount_point_obj)
    fail("it's currently not possible to grow the filesystem within lvm that's within an image") if create_lvm?(mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    size = mount_point_obj.config[:size]
    run_task(name, "grow #{underscore_name}",
             :task => lambda { cmd "qemu-img resize #{device(underscore_name)} #{size}" })
    rebuild_partition(name, mount_point_obj)
    check_and_resize_filesystem(name, mount_point_obj)
  end

  def shrink_filesystem(name, mount_point_obj)
    fail("it's currently not possible to shrink the filesystem within lvm that's within an image") if create_lvm?(mount_point_obj)
    check_and_resize_filesystem(name, mount_point_obj, :minimum)
    rebuild_partition(name, mount_point_obj, :minimum)
    underscore_name = underscore_name(name, mount_point_obj.name)

    newsize = `parted -sm #{device(underscore_name)} print | grep -e '^1:' | awk -F ':' '{ print $3 }'`

    run_task(name, "shrink image #{underscore_name}",
             :task => lambda { cmd "qemu-img resize #{device(underscore_name)} #{newsize}" })
  end

  def device(underscore_name)
    "#{@image_path}/#{underscore_name}.img"
  end

  def remove(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    FileUtils.remove_entry_secure(device(underscore_name)) if File.exists?(device(underscore_name))
  end

  def partition_name(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    if create_lvm?(mount_point_obj)
      vm_partition_name = cmd "kpartx -l #{device(underscore_name)} | grep -v 'loop deleted : /dev/loop' | " \
        "awk '{ print $1 }' | tail -1"
      fail "unable to work out vm_partition_name" if vm_partition_name.nil?
      vm_partition_name
    else
      mount_point_obj.get(:loopback_part)
    end
  end

  private

  def kb_from_size_string(size)
    unit = size[-1]
    multipliers = { :K => 1, :M => 1024, :G => 1024 * 1024 }
    size.chomp(unit).to_i * multipliers[unit.to_sym]
  end
end
