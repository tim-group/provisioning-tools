module Provision::Storage::Local

  def image_filesystem(name, prepare_options)
    image_file_path = prepare_options[:path] || '/var/local/images/gold/generic.img'
    run_task(name, {
      :task => lambda {
        case image_file_path
        when /^\/.*/
          raise "Source image file #{image_file_path} does not exist" if !File.exist?(image_file_path)
          cmd "dd if=#{image_file_path} of=#{device(name)}"
        when /^https?:\/\//
          cmd "curl -Ss --fail #{image_file_path} | dd of=#{device(name)}"
        else
          raise "Not sure how to deal with image_file_path: '#{image_file_path}'"
        end
      }
    })
  end

  def format_filesystem(name,prepare_options)
    fs_type = prepare_options[:type] || 'ext4'
    run_task(name, {
      :task => lambda {
        cmd "parted -s #{device(name)} mklabel msdos"
        cmd "parted -s #{device(name)} mkpart primary ext3 2048s 100%"
        cmd "kpartx -av #{device(name)}"
      }
    })
    run_task(name, {
      :task => lambda {
        cmd "mkfs.#{fs_type} /dev/mapper/#{partition_name(name)}"
      },
      :on_error => lambda {
        sleep 1
        cmd "kpartx -dv #{device(name)}"
      }
    })
    run_task(name, {
      :task => lambda {
        sleep 1
        cmd "kpartx -dv #{device(name)}"
      }
    })
  end

  def init_filesystem(name, settings = {})
    size = settings[:size]
    prepare = settings[:prepare] || {}
    prepare_options = prepare[:options] || {}
    method = prepare[:method].to_sym || :format
    resize = prepare_options.has_key?(:resize)? prepare_options[:resize] : true
    case method
    when :image
      image_filesystem(name, prepare_options)
      grow_filesystem(name, size, prepare_options) if resize
    when :format
      format_filesystem(name, prepare_options)
    else
      raise "unsure how to init storage using method '#{method}'"
    end
  end

  def partition_name(name)
    vm_partition_name = cmd "kpartx -l #{device(name)} | grep -v 'loop deleted : /dev/loop' | awk '{ print $1 }' | tail -1"
    raise "unable to work out vm_partition_name" if vm_partition_name.nil?
    return vm_partition_name
  end

  def rebuild_partition(name, prepare_options={})
    fs_type = prepare_options[:type] || 'ext4'
    run_task(name, {
      :task => lambda {
        cmd "parted -s #{device(name)} rm 1"
        cmd "parted -s #{device(name)} mkpart primary #{fs_type} 2048s 100%"
      }
    })
  end

  def check_and_resize_filesystem(name)
    vm_partition_name = partition_name(name)
    run_task(name, {
      :task => lambda {
        cmd "kpartx -av #{device(name)}"
      }
    })

    run_task(name, {
      :task => lambda {
        cmd "e2fsck -f -p /dev/mapper/#{vm_partition_name}"
        cmd "resize2fs /dev/mapper/#{vm_partition_name}"
      },
      :on_error => lambda {
        sleep 1
        cmd "kpartx -dv #{device(name)}"
      }
    })

    run_task(name, {
      :task => lambda {
        sleep 1
        cmd "kpartx -dv #{device(name)}"
      }
    })
  end

  def mount(name, dir, temp_mountpoint=false)
    dir_existed_at_start = File.exists? dir

    run_task(name, {
      :task => lambda {
        FileUtils.mkdir(dir) if temp_mountpoint and !dir_existed_at_start
      },
    })

    run_task(name, {
      :task => lambda {
        cmd "kpartx -av #{device(name)}"
      },
      :on_error => lambda {
        FileUtils.rmdir(dir) if temp_mountpoint and !dir_existed_at_start
      }
    })

    run_task(name, {
      :task => lambda {
        sleep 1
        cmd "mount /dev/mapper/#{partition_name(name)} #{dir}"
      },
      :on_error => lambda {
        sleep 1
        cmd "kpartx -dv #{device(name)}"
        FileUtils.rmdir(dir) if temp_mountpoint and dir_existed_at_start
      }
    })
  end

  def unmount(name, dir, delete_mountpoint=false)
    run_task(name, {
      :task => lambda {
        sleep 1
        cmd "umount #{dir}"
      },
      :on_error => lambda {
        sleep 1
        cmd "kpartx -dv #{device(name)}"
        FileUtils.rmdir(dir) if delete_mountpoint and dir_existed_at_start
      }
    })

    run_task(name, {
      :task => lambda {
        sleep 1
        cmd "kpartx -dv #{device(name)}"
        FileUtils.rmdir(dir) if delete_mountpoint and dir_existed_at_start
      }
    })
  end

  def libvirt_source(name)
    return "dev='#{device(name)}'"
  end

end

