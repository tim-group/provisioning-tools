require 'fileutils'
require 'provision/storage'
require 'provision/log'

class Provision::Storage::Service
  include Provision::Log

  def initialize(storage_options)
    @storage_types = {}
    storage_options.each do |storage_type, settings|
      arch = settings[:arch] || raise("Storage service requires each storage type to specify the 'arch' setting")
      options = settings[:options] || raise("Storage service requires each storage type to specify the 'options' setting")

      require "provision/storage/#{arch.downcase}"
      instance = Provision::Storage.const_get(arch).new(options)
      @storage_types[storage_type] = instance
    end
  end

  def prepare_storage(name, storage_spec, temp_dir)
    create_storage(name, storage_spec)
    init_filesystems(name, storage_spec)
    mount_filesystems(name, storage_spec, temp_dir)
  end

  def finish_preparing_storage(name, storage_spec, temp_dir)
    create_fstab(storage_spec, temp_dir)
    unmount_filesystems(name, storage_spec, temp_dir)
  end

  def cleanup(name)
    Provision::Storage.cleanup(name)
  end

  def get_storage(type)
    return @storage_types[type]
  end

  def create_storage(name, storage_spec)
    ordered_keys = order_keys(storage_spec.keys)

    ordered_keys.each do |mount_point|
      settings = storage_spec[mount_point]
      type = settings[:type].to_sym
      size = settings[:size]
      get_storage(type).create(name, size)
    end
  end

  def init_filesystems(name, storage_spec)
    ordered_keys = order_keys(storage_spec.keys)

    ordered_keys.each do |mount_point|
      settings = storage_spec[mount_point]
      storage = get_storage(settings[:type].to_sym)
      prepare = settings[:prepare] || {}

      case mount_point.to_s
      when '/'
        prepare.merge!({:method => :image}) if prepare[:method].nil?
        settings[:prepare] = prepare
      end
      storage.init_filesystem(name, settings)
    end
  end

  def mount_filesystems(name, storage_spec, tempdir)
    ordered_keys = order_keys(storage_spec.keys)

    ordered_keys.each do |mount_point|
      actual_mount_point = "#{tempdir}#{mount_point}"

      settings = storage_spec[mount_point]
      type = settings[:type].to_sym
      case mount_point
      when '/'
        get_storage(type).mount(name, actual_mount_point, true)
      else
        unless File.exists? actual_mount_point
          FileUtils.mkdir_p actual_mount_point
        end
        get_storage(type).mount(name, actual_mount_point, false)
      end
    end
  end

  def unmount_filesystems(name, storage_spec, tempdir)
    ordered_keys = order_keys(storage_spec.keys)

    ordered_keys.reverse.each do |mount_point|
      actual_mount_point = "#{tempdir}#{mount_point}"

      settings = storage_spec[mount_point]
      type = settings[:type].to_sym
      case mount_point
      when '/'
        get_storage(type).unmount(name, actual_mount_point, true)
      else
        get_storage(type).unmount(name, actual_mount_point, false)
      end
    end
  end

  def remove_storage(name, storage_spec)
    ordered_keys = order_keys(storage_spec.keys)

    ordered_keys.reverse.each do |mount_point|
      settings = storage_spec[mount_point]
      type = settings[:type].to_sym
      get_storage(type).remove(name)
    end
  end

  def spec_to_xml(name, storage_spec)
    template_file = "#{Provision.base}/templates/disk.template"
    xml_output = ""
    drive_letters = ('a'..'z').to_a
    current_drive_letter = 0
    ordered_keys = order_keys(storage_spec.keys)

    ordered_keys.each do |mount_point|
      settings = storage_spec[mount_point]
      type = settings[:type].to_sym
      storage = get_storage(type)
      source = storage.libvirt_source(name)
      virtio = settings[:prepare][:options][:virtio] rescue true
      disk_type = virtio ? 'vd' : 'hd'
      bus = virtio ? 'virtio' : 'ide'
      target = "dev='#{disk_type}#{drive_letters[current_drive_letter]}'"
      template = ERB.new(File.read(template_file))
      xml_output = xml_output + template.result(binding)
      current_drive_letter = current_drive_letter + 1
    end
    xml_output
  end

  def create_fstab(storage_spec, tempdir)
    fstab = "#{tempdir}/etc/fstab"
    drive_letters = ('a'..'z').to_a
    current_drive_letter = 0

    ordered_keys = order_keys(storage_spec.keys)

    ordered_keys.each do |mount_point|
      prepare_options = storage_spec[mount_point][:prepare][:options] rescue nil
      create_in_fstab = prepare_options[:create_in_fstab] rescue true
      if create_in_fstab
        File.open(fstab, 'a') do |f|
          fstype = 'ext4'
          begin
            fstype = prepare_options[:type] rescue 'ext4'
          rescue NoMethodError=>e
            if e.name == '[]'.to_sym
              log.debug "fstype not found, using default value: #{fstype}"
            else
              raise e
            end
          end
          f.puts("/dev/vd#{drive_letters[current_drive_letter]}1 #{mount_point}  #{fstype} defaults 0 0")
          current_drive_letter = current_drive_letter + 1
        end
      end
    end
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
