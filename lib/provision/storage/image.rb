require 'provision/storage/local'

class Provision::Storage::Image < Provision::Storage
  include Provision::Storage::Local

  def initialize(options)
    raise "Image storage requires a path as an option, named path" if options[:image_path].nil?
    @image_path = options[:image_path]
    super(options)

  end

  def create(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    size = mount_point_obj.config[:size]
    raise "Image file #{device(underscore_name)} already exists" if File.exist?("#{device(underscore_name)}")
    run_task(name, {
      :task => lambda {
        cmd "qemu-img create #{device(underscore_name)} #{size}"
      },
      :cleanup => lambda {
        remove(underscore_name)
      }
    })
  end

  def grow_filesystem(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    size = mount_point_obj.config[:size]
    run_task(name, {
      :task => lambda {
        cmd "qemu-img resize #{device(underscore_name)} #{size}"
      },
    })
    rebuild_partition(name, mount_point_obj)
    check_and_resize_filesystem(name, mount_point_obj)
  end

  def device(underscore_name)
    "#{@image_path}/#{underscore_name}.img"
  end

  def remove(underscore_name)
    FileUtils.remove_entry_secure device(underscore_name)
  end

  def partition_name(name, mount_point_obj)
    return mount_point_obj.get(:loopback_part)
  end

end
