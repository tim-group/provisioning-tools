require 'provision/storage/local'

class Provision::Storage::LVM < Provision::Storage
  include Provision::Storage::Local

  def initialize(options)
    raise "LVM storage requires a volume group as an option, named vg" if options[:vg].nil?
    super(options)
  end

  def create(name, size)
    if File.exists?("#{device(name)}")
      raise "Logical volume #{name} already exists in volume group #{@options[:vg]}"
    end
    run_task(name, {
      :task => lambda {
        cmd "lvcreate -n #{name} -L #{size} #{@options[:vg]}"
      },
      :cleanup => lambda {
        remove(name)
      }
    })
  end

  def grow_filesystem(name, size, options_hash={})
    rebuild_partition(name, options_hash)
    check_and_resize_filesystem(name)
  end

  def device(name)
    return "/dev/#{@options[:vg]}/#{name}"
  end

  def remove(name)
    cmd "lvremove -f #{device(name)}"
  end
end
