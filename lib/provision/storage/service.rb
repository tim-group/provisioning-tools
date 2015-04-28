require 'fileutils'
require 'provision/storage'
require 'provision/storage/config'
require 'provision/logger'

class Provision::Storage::Service
  attr_accessor :default_persistence_options

  def initialize(storage_options)
    @storage_types = {}
    storage_options.each do |storage_type, settings|
      arch = settings[:arch] || fail("Storage service requires each storage type to specify the 'arch' setting")
      options = settings[:options] || fail("Storage service requires each storage type to specify the " \
                                            "'options' setting")

      require "provision/storage/#{arch.downcase}"
      instance = Provision::Storage.const_get(arch).new(options)
      @storage_types[storage_type] = instance
      @storage_configs = {}
      @log = Provision::Logger.get_logger('storage')
    end
  end

  def prepare_storage(name, temp_dir)
    create_storage(name)
    init_filesystems(name)
    mount_filesystems(name, temp_dir)
  end

  def finish_preparing_storage(name, temp_dir)
    create_fstab(name, temp_dir)
    unmount_filesystems(name)
    post_unmount_tasks(name)
    Provision::Storage.finished(name)
  end

  def create_config(name, storage_spec)
    @storage_configs[name] = Provision::Storage::Config.new(storage_spec)
  end

  def cleanup(name)
    Provision::Storage.cleanup(name)
  end

  def get_storage(type)
    @storage_types[type]
  end

  def get_host_device(name, mount_point)
    mount_point_obj = @storage_configs[name].mount_point(mount_point)
    storage = get_storage(mount_point_obj.config[:type].to_sym)
    storage.device(storage.underscore_name(name, mount_point_obj.name))
  end

  def get_host_device_partition(name, mount_point)
    mount_point_obj = @storage_configs[name].mount_point(mount_point)
    storage = get_storage(mount_point_obj.config[:type].to_sym)
    storage.partition_name(name, mount_point_obj)
  end

  def get_mount_point(name, mount_point)
    @storage_configs[name].mount_point(mount_point)
  end

  def get_mount_point_config(name, mount_point)
    @storage_configs[name].mount_point(mount_point).config
  end

  def create_storage(name)
    @storage_configs[name].mount_points.each do |mount_point|
      mount_point_obj = get_mount_point(name, mount_point)
      type = mount_point_obj.config[:type].to_sym
      persistent = mount_point_obj.config[:persistent]
      fail 'Persistent options not found' unless mount_point_obj.config.key?(:persistence_options)
      storage = get_storage(type)
      if persistent
        storage.check_persistent_storage(name, mount_point_obj)
      else
        storage.create(name, mount_point_obj)
        mount_point_obj.set(:newly_created, true)
      end
    end
  end

  def init_filesystems(name)
    @storage_configs[name].mount_points.each do |mount_point|
      mount_point_obj = get_mount_point(name, mount_point)
      type = mount_point_obj.config[:type].to_sym
      persistent = mount_point_obj.config[:persistent]
      newly_created = mount_point_obj.get(:newly_created)
      storage = get_storage(type)
      storage.init_filesystem(name, mount_point_obj) if newly_created
    end
  end

  def mount_filesystems(name, tempdir)
    @storage_configs[name].mount_points.each do |mount_point|
      mount_point_obj = get_mount_point(name, mount_point)
      actual_mount_point = "#{tempdir}#{mount_point}"
      mount_point_obj.set(:actual_mount_point, actual_mount_point)
      mount_point_obj.set(:temp_mount_point, true) if mount_point.to_s == '/'

      type = mount_point_obj.config[:type].to_sym
      storage = get_storage(type)

      unless mount_point.to_s == '/'
        unless File.exists? actual_mount_point
          FileUtils.mkdir_p actual_mount_point
        end
      end

      storage.mount(name, mount_point_obj)
    end
  end

  def unmount_filesystems(name)
    @storage_configs[name].mount_points.reverse_each do |mount_point|
      mount_point_obj = get_mount_point(name, mount_point)

      type = mount_point_obj.config[:type].to_sym
      storage = get_storage(type)

      storage.unmount(name, mount_point_obj)

      mount_point_obj.unset(:actual_mount_point)
      mount_point_obj.unset(:temp_mount_point)
    end
  end

  def post_unmount_tasks(name)
    @storage_configs[name].mount_points.reverse_each do |mount_point|
      mount_point_obj = get_mount_point(name, mount_point)

      type = mount_point_obj.config[:type].to_sym
      storage = get_storage(type)

      shrink = mount_point_obj.config[:prepare][:options][:shrink_after_unmount]
      storage.shrink_filesystem(name, mount_point_obj) if shrink
    end
  end

  def remove_storage(name)
    @storage_configs[name].mount_points.each do |mount_point|
      mount_point_obj = get_mount_point(name, mount_point)
      type = mount_point_obj.config[:type].to_sym
      persistent = mount_point_obj.config[:persistent]
      storage = get_storage(type)
      if persistent
        @log.info "Unable to remove storage for #{mount_point} on #{name}, storage is marked as persistent, "
      else
        @log.debug "Removing storage for #{mount_point} on #{name}"
        storage.remove(name, mount_point)
      end
    end
  end

  def spec_to_xml(name)
    template_file = "#{Provision.base}/templates/disk.template"
    xml_output = ""
    drive_letters = ('a'..'z').to_a
    current_drive_letter = 0

    @storage_configs[name].mount_points.each do |mount_point|
      mount_point_obj = get_mount_point(name, mount_point)
      type = mount_point_obj.config[:type].to_sym
      storage = get_storage(type)
      source = storage.libvirt_source(name, mount_point_obj.name)
      virtio = mount_point_obj.config[:prepare][:options][:virtio]
      disk_type = virtio ? 'vd' : 'hd'
      bus = virtio ? 'virtio' : 'ide'
      target = "dev='#{disk_type}#{drive_letters[current_drive_letter]}'"
      template = ERB.new(File.read(template_file))
      xml_output += template.result(binding)
      current_drive_letter += 1
    end
    xml_output
  end

  def create_fstab(name, tempdir)
    fstab = "#{tempdir}/etc/fstab"
    drive_letters = ('a'..'z').to_a
    current_drive_letter = 0

    @storage_configs[name].mount_points.each do |mount_point|
      mount_point_obj = get_mount_point(name, mount_point)
      prepare_options = mount_point_obj.config[:prepare][:options]
      create_in_fstab = prepare_options[:create_in_fstab]
      next if !create_in_fstab

      File.open(fstab, 'a') do |f|
        fstype = 'ext4'
        begin
          fstype = prepare_options[:type]
        rescue NoMethodError => e
          if e.name == '[]'.to_sym
            @log.debug "fstype not found, using default value: #{fstype}"
          else
            raise e
          end
        end
        f.puts("/dev/vd#{drive_letters[current_drive_letter]}1 #{mount_point_obj.name}  #{fstype} defaults 0 0")
        current_drive_letter += 1
      end
    end
  end

  # FIXME: This function doens't really work like the others. It was created
  # as a way to copy from an mcollective agent, because of that there's no spec
  # to work from, so we have to provide all the details ourself
  def copy(name, storage_type, mount_point, transport, transport_options)
    storage = @storage_types[storage_type.to_sym]
    mount_point_obj = Provision::Storage::MountPoint.new(mount_point, {})
    storage.copy_to(name, mount_point_obj, transport, transport_options)
  end
end
