require 'provisioning-tools/provision/logger'

module Provision::Storage::Local
  @@logger = Provision::Logger.get_logger('storage')

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
      fail "unsure how to init storage using method '#{method}'"
    end
  end

  def image_filesystem(name, mount_point_obj)
    fail("it's currently not possible to image a filesystem within lvm that's within lvm or an image") if create_lvm?(mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    image_file_path = mount_point_obj.config[:prepare][:options][:path]

    run_task(name, "image #{underscore_name}", :task => lambda do
      case image_file_path
      when /^\/.*/
        fail "Source image file #{image_file_path} does not exist" if !File.exist?(image_file_path)
        cmd "dd bs=1M if=#{image_file_path} of=#{device(underscore_name)}"
      when /^https?:\/\//
        cmd "curl -Ss --fail #{image_file_path} | dd bs=1M of=#{device(underscore_name)}"
      else
        fail "Not sure how to deal with image_file_path: '#{image_file_path}'"
      end
    end)
  end

  def format_filesystem(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    fs_type = mount_point_obj.config[:prepare][:options][:type]
    guest_device = create_lvm?(mount_point_obj) ? guest_device(name, mount_point_obj) : device(underscore_name)

    unless create_lvm?(mount_point_obj)
      run_task(name, "create partition on #{guest_device}", :task => lambda do
        cmd "parted -s #{guest_device} mklabel msdos"
        cmd "parted -s #{guest_device} mkpart primary #{fs_type} 2048s 100%"
      end)

      run_task(name, "create partition device nodes #{guest_device}",
               :task => create_lvm?(mount_point_obj) ? lambda { kpartxa_new(guest_device) } : lambda { kpartxa(name, mount_point_obj) },
               :cleanup => create_lvm?(mount_point_obj) ? lambda { kpartxd_new(guest_device) } : lambda { kpartxd(name, mount_point_obj) })
    end

    partition_name = if create_lvm?(mount_point_obj)
                       guest_device(name, mount_point_obj)
                     else
                       "/dev/mapper/#{partition_name(name, mount_point_obj)}"
                     end

    run_task(name, "create filesystem on #{partition_name}", :task => lambda do
      usage_type = mount_point_obj.config[:prepare][:options][:usage_type]
      if usage_type.nil?
        cmd "mkfs.#{fs_type} #{partition_name}"
      else
        cmd "mkfs.#{fs_type} -T #{usage_type} #{partition_name}"
      end
    end)

    return if create_lvm?(mount_point_obj)

    run_task(name, "undo create partition device nodes #{guest_device}",
             :task => create_lvm?(mount_point_obj) ? lambda { kpartxd_new(guest_device) } : lambda { kpartxd(name, mount_point_obj) },
             :remove_cleanup => "create partition device nodes #{guest_device}")
  end

  def rebuild_partition(name, mount_point_obj, size = :maximum)
    fail("it's not possible to rebuild a partition that's within lvm that's within lvm or an image file") if create_lvm?(mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    fs_type = mount_point_obj.config[:prepare][:options][:type]

    case size
    when :maximum
      run_task(name, "resize partition #{underscore_name}", :task => lambda do
        cmd "parted -s #{device(underscore_name)} rm 1"
        cmd "parted -s #{device(underscore_name)} mkpart primary #{fs_type} 2048s 100%"
      end)
    when :minimum
      run_task(name, "create partition device nodes #{underscore_name}",
               :task => lambda { kpartxa(name, mount_point_obj) },
               :cleanup => lambda { kpartxd(name, mount_point_obj) })

      vm_partition_name = partition_name(name, mount_point_obj)
      blockcount = cmd("dumpe2fs -h /dev/mapper/#{vm_partition_name} | grep -F 'Block count:' | " \
        "awk -F ':' '{ print $2 }' | sed 's/ //g'").chomp.to_i
      blocksize = cmd("dumpe2fs -h /dev/mapper/#{vm_partition_name} | grep -F 'Block size:' | " \
        "awk -F ':' '{ print $2 }' | sed 's/ //g'").chomp.to_i
      sectors = (blockcount * blocksize / 512) + 2048

      kpartxd(name, mount_point_obj)

      underscore_name = underscore_name(name, mount_point_obj.name)
      run_task(name, "resize partition #{underscore_name}", :task => lambda do
        cmd "parted -s #{device(underscore_name)} rm 1"
        cmd "parted -s #{device(underscore_name)} mkpart primary #{fs_type} 2048s #{sectors}s"
      end)

      run_task(name, "undo create partition device nodes #{underscore_name}",
               :task => lambda { kpartxd(name, mount_point_obj) },
               :remove_cleanup => "create partition device nodes #{underscore_name}")
    end
  end

  def check_persistent_storage(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    size = mount_point_obj.config[:size]
    persistence_options = mount_point_obj.config[:persistence_options]
    if !File.exist?("#{device(underscore_name)}")
      @@logger.info("Persistent storage #{device(underscore_name)} does not exist")
      case persistence_options[:on_storage_not_found]
      when 'raise_error'
        fail "Persistent storage was not found for #{device(underscore_name)}"
      when 'create_new'
        create(name, mount_point_obj)
        mount_point_obj.set(:newly_created, true)
      else
        fail "Persistent storage option on_storage_not_found set to unknown setting: '#{persistence_options[:on_storage_not_found]}'"
      end
    else
      @@logger.info("Persistent storage #{device(underscore_name)} exists")
      return unless create_lvm?(mount_point_obj)
      host_device = host_device(name, mount_point_obj)
      create_partition_device_nodes_task(name, host_device)
    end
  end

  def check_and_resize_filesystem(name, mount_point_obj, resize = :maximum)
    fail("its not possible to check and resize the filesystem within lvm thats within lvm or an image file") if create_lvm?(mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    run_task(name, "create partition device nodes #{underscore_name}",
             :task => lambda { kpartxa(name, mount_point_obj) },
             :cleanup => lambda { kpartxd(name, mount_point_obj) })

    vm_partition_name = partition_name(name, mount_point_obj)
    run_task(name, "check and resize filesystem #{vm_partition_name}", :task => lambda do
      cmd "e2fsck -f -p /dev/mapper/#{vm_partition_name}"
      case resize
      when :maximum
        cmd "resize2fs /dev/mapper/#{vm_partition_name}"
      when :minimum
        cmd "resize2fs -M /dev/mapper/#{vm_partition_name}"
      when false
        # no action
      else
        fail "unsure how to deal with resize option: #{resize}"
      end
    end)

    run_task(name, "undo create partition device nodes #{underscore_name}",
             :task => lambda { kpartxd(name, mount_point_obj) },
             :remove_cleanup => "create partition device nodes #{underscore_name}")
  end

  def kpartxa(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    the_device = device(underscore_name)
    cmd "udevadm settle"
    output = cmd "kpartx -av #{the_device}"
    if output =~ /^add map (loop\d+)(p\d+) \(\d+:\d+\): \d+ \d+ linear \/dev\/loop\d+ \d+$/
      mount_point_obj.set(:loopback_dev, Regexp.last_match(1))
      mount_point_obj.set(:loopback_part, "#{Regexp.last_match(1)}#{Regexp.last_match(2)}")
    end
    sleep 1
  end

  def kpartxd(name, mount_point_obj)
    loopback = mount_point_obj.get(:loopback_dev)

    sleep 1
    cmd "udevadm settle"

    if loopback
      cmd "kpartx -dv /dev/#{loopback}"
      cmd "losetup -dv /dev/#{loopback}"
      mount_point_obj.unset(:loopback_part)
      mount_point_obj.unset(:loopback_dev)
    else
      cmd "udevadm settle"
      underscore_name = underscore_name(name, mount_point_obj.name)
      the_device = device(underscore_name)
      cmd "kpartx -dv #{the_device}"
    end
  end

  def underscorize(string)
    "#{string.to_s.tr('/', '_').gsub(/_$/, '')}"
  end

  def underscore_name(name, mount_point)
    "#{name}#{mount_point.to_s.tr('/', '_').gsub(/_$/, '')}"
  end

  def mount(name, mount_point_obj)
    dir = mount_point_obj.get(:actual_mount_point)
    temp_mountpoint = mount_point_obj.get(:temp_mount_point)
    chmod = mount_point_obj.config[:chmod]

    underscore_name = underscore_name(name, mount_point_obj.name)
    guest_device = create_lvm?(mount_point_obj) ? guest_device(name, mount_point_obj) : underscore_name
    dir_existed_at_start = File.exists? dir

    run_task(name, "make directory #{dir}",
             :task => lambda { FileUtils.mkdir(dir) if temp_mountpoint && !dir_existed_at_start },
             :cleanup => lambda { FileUtils.rmdir(dir) if temp_mountpoint && !dir_existed_at_start })

    unless create_lvm?(mount_point_obj)
      run_task(name, "create partition device nodes #{guest_device}",
               :task => create_lvm?(mount_point_obj) ? lambda { kpartxa_new(guest_device) } : lambda { kpartxa(name, mount_point_obj) },
               :cleanup => create_lvm?(mount_point_obj) ? lambda { kpartxd_new(guest_device) } : lambda { kpartxd(name, mount_point_obj) })
    end

    part_name = if create_lvm?(mount_point_obj)
                  guest_device(name, mount_point_obj)
                else
                  "/dev/mapper/#{partition_name(name, mount_point_obj)}"
                end
    run_task(name, "mount #{part_name} on #{dir}",
             :task => lambda do
               sleep 1
               cmd "mount #{part_name} #{dir}"
             end,
             :cleanup => lambda { cmd "umount #{dir}" })

    if chmod
      run_task(name, "chmod directory #{dir}",
               :task => lambda { FileUtils.chmod(chmod, dir) })
    end

    mount_point_obj.set(:dir_existed_at_start, dir_existed_at_start)
  end

  def unmount(name, mount_point_obj)
    dir = mount_point_obj.get(:actual_mount_point)
    delete_mountpoint = mount_point_obj.get(:temp_mount_point)
    dir_existed_at_start = mount_point_obj.get(:dir_existed_at_start)

    underscore_name = underscore_name(name, mount_point_obj.name)
    guest_device = create_lvm?(mount_point_obj) ? guest_device(name, mount_point_obj) : underscore_name
    part_name = create_lvm?(mount_point_obj) ? guest_device(name, mount_point_obj) : partition_name(name, mount_point_obj)

    run_task(name, "undo mount #{part_name} on #{dir}",
             :task => lambda do
               sleep 1
               cmd "umount #{dir}"
             end,
             :remove_cleanup => "mount #{part_name} on #{dir}")

    unless create_lvm?(mount_point_obj)
      run_task(name, "undo create partition device nodes #{guest_device}",
               :task => create_lvm?(mount_point_obj) ? lambda { kpartxd_new(guest_device) } : lambda { kpartxd(name, mount_point_obj) },
               :remove_cleanup => "create partition device nodes #{guest_device}")
    end

    run_task(name, "undo make directory #{dir}",
             :task => lambda { FileUtils.rmdir(dir) if delete_mountpoint && dir_existed_at_start },
             :remove_cleanup => "make directory #{dir}")

    mount_point_obj.unset(:dir_existed_at_start)
  end

  def libvirt_source(name, mount_point)
    underscore_name = underscore_name(name, mount_point)
    "dev='#{device(underscore_name)}'"
  end

  def create_lvm?(mount_point_obj)
    mount_point_obj.config[:prepare][:options][:create_guest_lvm]
  rescue
    false
  end

  def lvm_device_name(name, mount_point_obj)
    underscore_name = underscore_name(name, mount_point_obj.name)
    "/dev/#{underscore_name}/#{underscore_name('', mount_point_obj.name)}"
  end

  def copy_to(name, mount_point_obj, transport_string, transport_options)
    source_device = device(underscore_name(name, mount_point_obj.name))
    fail Provision::Storage::StorageNotFoundError, "Source device: #{source_device} does not exist" \
      unless File.exists?(source_device)

    transports = transport_string.split(',')
    transports.map!(&:to_sym)

    options = {}
    transports.each do |transport|
      options[transport] = {}
    end

    split_opts = transport_options.split(',')
    split_opts.each do |opt|
      temp_key, value = opt.split(':')
      transport, option = temp_key.split('__', 2)
      fail "option: #{option} for unused transport: #{transport} provided" if options[transport.to_sym].nil?
      options[transport.to_sym][option.to_sym] = value
    end

    copy_cmd = ""
    last_cmd = :start
    last_cmd_provides_output = false

    transports.each do |transport|
      t_options = options[transport]
      case transport
      when :dd_from_source
        fail "transport #{transport} does not expect any input, but previous command #{last_cmd} provides output" \
          if last_cmd_provides_output == true || last_cmd == :ssh_cmd
        copy_cmd = "#{copy_cmd}dd if=#{source_device}"
        last_cmd_provides_output = true
      when :dd_of
        fail "transport #{transport} expects input, but previous command #{last_cmd} provides no output" \
          if last_cmd_provides_output == false && last_cmd != :ssh_cmd
        copy_cmd = "#{copy_cmd} | " if last_cmd_provides_output == true
        [:path].each do |opt|
          fail "transport #{transport} requires option #{opt}" if t_options[opt].nil?
        end
        copy_cmd = "#{copy_cmd}dd of=#{t_options[:path]}"
        last_cmd_provides_output = false
      when :gzip
        fail "transport #{transport} expects input, but previous command #{last_cmd} provides no output" \
          if last_cmd_provides_output == false && last_cmd != :ssh_cmd
        copy_cmd = "#{copy_cmd} | " if last_cmd_provides_output == true
        copy_cmd = "#{copy_cmd}gzip"
        last_cmd_provides_output = true
      when :gunzip
        fail "transport gunzip expects input, but previous command #{last_cmd} provides no output" \
          if last_cmd_provides_output == false && last_cmd != :ssh_cmd
        copy_cmd = "#{copy_cmd} | " if last_cmd_provides_output == true
        copy_cmd = "#{copy_cmd}gunzip"
        last_cmd_provides_output = true
      when :ssh_cmd
        fail "transport #{transport} expects input, but previous command #{last_cmd} provides no output" \
          if last_cmd_provides_output == false
        [:host, :username].each do |opt|
          fail "transport #{transport} requires option #{opt}" if t_options[opt].nil?
        end
        copy_cmd = "#{copy_cmd} | ssh"
        copy_cmd = "#{copy_cmd} -i #{t_options[:key]}" if t_options[:key]
        copy_cmd = "#{copy_cmd} -o StrictHostKeyChecking=no #{t_options[:username]}@#{t_options[:host]} '"
        last_cmd_provides_output = false
      when :end_ssh_cmd
        fail "transport #{transport} does not expect any input, but previous command #{last_cmd} provides output" \
          if last_cmd_provides_output == true || last_cmd == :ssh_cmd
        copy_cmd = "#{copy_cmd}'"
        last_cmd_provides_output = false
      else
        fail "Unknown transport: #{transport}"
      end
      last_cmd = transport
    end

    output = nil
    run_task(name, copy_cmd, :task => lambda do
      output = cmd "#{copy_cmd}"
    end)
    output
  end
end
