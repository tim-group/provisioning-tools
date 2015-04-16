require 'provision/storage/mount_point'

class Provision::Storage::Config
  def initialize(storage_spec)
    @mount_points = {}
    order_keys(storage_spec.keys).each do |mount_point|
      @mount_points[mount_point] = Provision::Storage::MountPoint.new(mount_point, storage_spec[mount_point])
    end
  end

  def mount_points
    order_keys(@mount_points.keys)
  end

  def mount_point(mount_point)
    @mount_points[mount_point]
  end

  private

  def order_keys(keys)
    keys.map! do |key|
      key.to_s
    end
    keys.sort!
    keys.map! do |key|
      key.to_sym
    end
    keys
  end
end
