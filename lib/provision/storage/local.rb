module Provision::Storage::Local

  def image_filesystem(name, mount_point, prepare_options)
    underscore_name = underscore_name(name, mount_point)
    image_file_path = prepare_options[:path] || '/var/local/images/gold/generic.img'
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

  def format_filesystem(name, mount_point, prepare_options)
    underscore_name = underscore_name(name, mount_point)
    fs_type = prepare_options[:type] || 'ext4'
    run_task(name, {
      :task => lambda {
        cmd "parted -s #{device(underscore_name)} mklabel msdos"
        cmd "parted -s #{device(underscore_name)} mkpart primary ext3 2048s 100%"
        cmd "kpartx -av #{device(underscore_name)}"
      }
    })
    run_task(name, {
      :task => lambda {
        cmd "mkfs.#{fs_type} /dev/mapper/#{partition_name(underscore_name)}"
      },
      :on_error => lambda {
        sleep 1
        cmd "kpartx -dv #{device(underscore_name)}"
      }
    })
    run_task(name, {
      :task => lambda {
        sleep 1
        cmd "kpartx -dv #{device(underscore_name)}"
      }
    })
  end

  def init_filesystem(name, mount_point, settings = {})
    size = settings[:size]
    prepare = settings[:prepare] || {}
    prepare_options = prepare[:options] || {}
    method = prepare[:method].to_sym rescue :format
    resize = prepare_options.has_key?(:resize)? prepare_options[:resize] : true
    case method
    when :image
      image_filesystem(name, mount_point, prepare_options)
      grow_filesystem(name, mount_point, size, prepare_options) if resize
    when :format
      format_filesystem(name, mount_point, prepare_options)
    else
      raise "unsure how to init storage using method '#{method}'"
    end
  end

  def partition_name(underscore_name)
    vm_partition_name = cmd "kpartx -l #{device(underscore_name)} | grep -v 'loop deleted : /dev/loop' | awk '{ print $1 }' | tail -1"
    raise "unable to work out vm_partition_name" if vm_partition_name.nil?
    return vm_partition_name
  end

  def rebuild_partition(name, mount_point, prepare_options={})
    underscore_name = underscore_name(name, mount_point)
    fs_type = prepare_options[:type] || 'ext4'
    run_task(name, {
      :task => lambda {
        cmd "parted -s #{device(underscore_name)} rm 1"
        cmd "parted -s #{device(underscore_name)} mkpart primary #{fs_type} 2048s 100%"
      }
    })
  end

  def check_and_resize_filesystem(name, mount_point)
    underscore_name = underscore_name(name, mount_point)
    vm_partition_name = partition_name(underscore_name)
    run_task(name, {
      :task => lambda {
        cmd "kpartx -av #{device(underscore_name)}"
      }
    })

    run_task(name, {
      :task => lambda {
        cmd "e2fsck -f -p /dev/mapper/#{vm_partition_name}"
        cmd "resize2fs /dev/mapper/#{vm_partition_name}"
      },
      :on_error => lambda {
        sleep 1
        cmd "kpartx -dv #{device(underscore_name)}"
      }
    })

    run_task(name, {
      :task => lambda {
        sleep 1
        cmd "kpartx -dv #{device(underscore_name)}"
      }
    })
  end

  def underscore_name(name, mount_point)
    "#{name}#{mount_point.to_s.gsub('/','_').gsub(/_$/, '')}"
  end

  def mount(name, mount_point, dir, temp_mountpoint=false)
    underscore_name = underscore_name(name, mount_point)
    dir_existed_at_start = File.exists? dir

    run_task(name, {
      :task => lambda {
        FileUtils.mkdir(dir) if temp_mountpoint and !dir_existed_at_start
      },
    })

    run_task(name, {
      :task => lambda {
        cmd "kpartx -av #{device(underscore_name)}"
      },
      :on_error => lambda {
        FileUtils.rmdir(dir) if temp_mountpoint and !dir_existed_at_start
      }
    })

    run_task(name, {
      :task => lambda {
        sleep 1
        cmd "mount /dev/mapper/#{partition_name(underscore_name)} #{dir}"
      },
      :on_error => lambda {
        sleep 1
        cmd "kpartx -dv #{device(underscore_name)}"
        FileUtils.rmdir(dir) if temp_mountpoint and dir_existed_at_start
      }
    })
  end

  def unmount(name, mount_point, dir, delete_mountpoint=false)
    underscore_name = underscore_name(name, mount_point)
    run_task(name, {
      :task => lambda {
        sleep 1
        cmd "umount #{dir}"
      },
      :on_error => lambda {
        sleep 1
        cmd "kpartx -dv #{device(underscore_name)}"
        FileUtils.rmdir(dir) if delete_mountpoint and dir_existed_at_start
      }
    })

    run_task(name, {
      :task => lambda {
        sleep 1
        cmd "kpartx -dv #{device(underscore_name)}"
        FileUtils.rmdir(dir) if delete_mountpoint and dir_existed_at_start
      }
    })
  end

  def libvirt_source(name, mount_point)
    underscore_name = underscore_name(name, mount_point)
    return "dev='#{device(underscore_name)}'"
  end

end

