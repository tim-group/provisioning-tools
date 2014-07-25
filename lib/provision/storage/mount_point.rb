class Provision::Storage::Mount_point

  attr_reader :name, :config

  def initialize(mount_point, mount_point_spec)
    @name = mount_point
    default_config = {
      :persistent => false,
      :persistence_options => {
        :on_storage_not_found     => :raise_error,
        :on_storage_size_mismatch => :raise_error
      },
      :prepare    => {
        :options => {
          :create_in_fstab => true,
          :resize          => true,
          :type            => 'ext4',
          :virtio          => true,
        }
      },
      :size       =>"3G",
    }

    if mount_point == '/'.to_sym
      default_config = recurse_merge(default_config, {
        :prepare => {
          :method => "image",
          :options => {
            :path => "/var/local/images/gold/generic.img"
          }
        }
      })
    else
      default_config = recurse_merge(default_config, {
        :prepare => {
          :method => 'format',
          :options => {
          }
        }
      })
    end

    @config = recurse_merge(default_config, mount_point_spec)
    @temp_data = {}
  end

  def set(key, value)
    @temp_data[key] = value
  end

  def unset(key)
    @temp_data.delete(key)
  end

  def get(key)
    return @temp_data[key]
  end

  private
  def recurse_merge(a,b)
    a.merge(b) do |_,x,y|
      (x.is_a?(Hash) && y.is_a?(Hash)) ? recurse_merge(x,y) : y
    end
  end
end
