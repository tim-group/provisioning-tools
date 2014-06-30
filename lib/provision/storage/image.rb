require 'provision/storage/local'

class Provision::Storage::Image < Provision::Storage
  include Provision::Storage::Local

  def initialize(options)
    raise "Image storage requires a path as an option, named path" if options[:image_path].nil?
    @image_path = options[:image_path]
    super(options)

  end

  def create(name, size)
    raise "Image file #{device(name)} already exists" if File.exist?("#{device(name)}")
    run_task(name, {
      :task => lambda {
        cmd "qemu-img create #{device(name)} #{size}"
      },
      :cleanup => lambda {
        remove(name)
      }
    })
  end

  def grow_filesystem(name, size, options_hash={})
    run_task(name, {
      :task => lambda {
        cmd "qemu-img resize #{device(name)} #{size}"
      },
      :cleanup => lambda {
        remove(name)
      }
    })
    rebuild_partition(name, options_hash)
    check_and_resize_filesystem(name)
  end

  def device(name)
    "#{@image_path}/#{name}"
  end

  def remove(name)
    FileUtils.remove_entry_secure device(name)
  end
end
