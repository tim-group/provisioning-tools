module Provision::Storage::Local

  def init_filesystem(name, mount_point_obj)
    size = mount_point_obj.config[:size]
    prepare = mount_point_obj.config[:prepare]
    method = prepare[:method].to_sym
    resize = prepare[:options][:resize]
    case method
    when :image
      image_filesystem(name, mount_point_obj)
      grow_filesystem(name, mount_point_obj) if resize
    when :format
      format_filesystem(name, mount_point_obj)
    else
      raise "unsure how to init storage using method '#{method}'"
    end
  end

  def image_filesystem(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    image_file_path = mount_point_obj.config[:prepare][:options][:path]

    run_task(name, {
      :task => lambda {
        case image_file_path
        when /^\/.*/
          raise "Source image file #{image_file_path} does not exist" if !File.exist?(image_file_path)
          cmd "dd if=#{image_file_path} of=#{device(underscore_name)}"
        when /^https?:\/\//
          cmd "curl -Ss --fail #{image_file_path} | dd of=#{device(underscore_name)}"
        else
          raise "Not sure how to deal with image_file_path: '#{image_file_path}'"
        end
      }
    })
  end

  def format_filesystem(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    fs_type = mount_point_obj.config[:prepare][:options][:type]

    run_task(name, {
      :task => lambda {
        cmd "parted -s #{device(underscore_name)} mklabel msdos"
        cmd "parted -s #{device(underscore_name)} mkpart primary ext3 2048s 100%"
        kpartxa(name, mount_point_obj)
      }
    })
    run_task(name, {
      :task => lambda {
        cmd "mkfs.#{fs_type} /dev/mapper/#{partition_name(name, mount_point_obj)}"
      },
      :on_error => lambda {
        kpartxd(name, mount_point_obj)
      }
    })
    run_task(name, {
      :task => lambda {
        kpartxd(name, mount_point_obj)
      }
    })
  end

  def rebuild_partition(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    fs_type = mount_point_obj.config[:prepare][:options][:type]
    run_task(name, {
      :task => lambda {
        cmd "parted -s #{device(underscore_name)} rm 1"
        cmd "parted -s #{device(underscore_name)} mkpart primary #{fs_type} 2048s 100%"
      }
    })
  end

  def check_persistent_storage(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    size = mount_point_obj.config[:size]
    persistence_options = mount_point_obj.config[:persistence_options]
    if !File.exist?("#{device(underscore_name)}")
      case persistence_options[:on_storage_not_found]
      when :raise_error
        raise "Persistent storage was not found for #{device(underscore_name)}"
      when :create_new
        create(name, mount_point_obj)
      end
    else
      check_and_resize_filesystem(name, mount_point_obj, false)
    end
  end

  def check_and_resize_filesystem(name, mount_point_obj, resize=true)
    run_task(name, {
      :task => lambda {
        kpartxa(name, mount_point_obj)
      }
    })

    vm_partition_name = partition_name(name, mount_point_obj)
    run_task(name, {
      :task => lambda {
        cmd "e2fsck -f -p /dev/mapper/#{vm_partition_name}"
        cmd "resize2fs /dev/mapper/#{vm_partition_name}" if resize
      },
      :on_error => lambda {
        kpartxd(name, mount_point_obj)
      }
    })

    run_task(name, {
      :task => lambda {
        kpartxd(name, mount_point_obj)
      }
    })
  end

  def kpartxa(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    output = cmd "kpartx -av #{device(underscore_name)}"
    if output =~ /^add map (loop\d+)(p\d+) \(\d+:\d+\): \d+ \d+ linear \/dev\/loop\d+ \d+$/
      mount_point_obj.set(:loopback_dev, $1)
      mount_point_obj.set(:loopback_part, "#{$1}#{$2}")
    end
    sleep 1
  end

  def kpartxd(name, mount_point_obj)
    loopback = mount_point_obj.get(:loopback_dev)

    sleep 1

    if loopback
      cmd "kpartx -dv /dev/#{loopback}"
      cmd "losetup -dv /dev/#{loopback}"
      mount_point_obj.unset(:loopback_part)
      mount_point_obj.unset(:loopback_dev)
    else
      underscore_name = underscore_name(name, mount_point_obj.name)
      cmd "kpartx -dv #{device(underscore_name)}"
    end
  end

  def underscore_name(name, mount_point)
    "#{name}#{mount_point.to_s.gsub('/','_').gsub(/_$/, '')}"
  end

  def mount(name, mount_point_obj)
    dir = mount_point_obj.get(:actual_mount_point)
    temp_mountpoint = mount_point_obj.get(:temp_mount_point)

    underscore_name = underscore_name(name, mount_point_obj.name)
    dir_existed_at_start = File.exists? dir

    run_task(name, {
      :task => lambda {
        FileUtils.mkdir(dir) if temp_mountpoint and !dir_existed_at_start
      },
    })

    run_task(name, {
      :task => lambda {
        kpartxa(name, mount_point_obj)
      },
      :on_error => lambda {
        FileUtils.rmdir(dir) if temp_mountpoint and !dir_existed_at_start
      }
    })

    run_task(name, {
      :task => lambda {
        sleep 1
        cmd "mount /dev/mapper/#{partition_name(name, mount_point_obj)} #{dir}"
      },
      :on_error => lambda {
        kpartxd(name, mount_point_obj)
        FileUtils.rmdir(dir) if temp_mountpoint and dir_existed_at_start
      }
    })

    mount_point_obj.set(:dir_existed_at_start, dir_existed_at_start)
  end

  def unmount(name, mount_point_obj)
    dir = mount_point_obj.get(:actual_mount_point)
    delete_mountpoint = mount_point_obj.get(:temp_mount_point)
    dir_existed_at_start = mount_point_obj.get(:dir_existed_at_start)

    underscore_name = underscore_name(name, mount_point_obj.name)
    run_task(name, {
      :task => lambda {
        sleep 1
        cmd "umount #{dir}"
      },
      :on_error => lambda {
        kpartxd(name, mount_point_obj)
        FileUtils.rmdir(dir) if delete_mountpoint and dir_existed_at_start
      }
    })

    run_task(name, {
      :task => lambda {
        kpartxd(name, mount_point_obj)
        FileUtils.rmdir(dir) if delete_mountpoint and dir_existed_at_start
      }
    })

    mount_point_obj.unset(:dir_existed_at_start)
  end

  def libvirt_source(name, mount_point)
    underscore_name = underscore_name(name, mount_point)
    return "dev='#{device(underscore_name)}'"
  end

end

