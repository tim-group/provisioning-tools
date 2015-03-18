require 'yaml'
require 'pp'

module MCollective
  module Agent
    class Computenodestorage < RPC::Agent
      def get_vg_data(volume_group)
        total = 0
        used = 0
        free = 0
        f = open("|vgdisplay #{volume_group} --units K")
        f.readlines.each do |line|
          if line.match(/Volume group "${volume_group}" not found/)
            raise line
          elsif line.match(/VG\s+Size/)
            total = line.match(/[\d.]+/).to_s
          elsif line.match(/Alloc\s+PE/)
            used = line.match(/ \/ [\d.]+/).to_s.match(/[\d.]+/).to_s
          elsif line.match(/Free\s+PE/)
            free = line.match(/ \/ [\d.]+/).to_s.match(/[\d.]+/).to_s
          end
        end
        f.close
        { :total => total.to_f.floor, :used => used.to_f.ceil, :free => free.to_f.floor }
      end

      def get_lv_data_for_vg(volume_group)
        lv_data = {}
        f = open("|lvdisplay #{volume_group} --units K")
        name = ''
        f.readlines.each do |line|
          if line.match(/Volume group "${volume_group}" not found/)
            raise line
          elsif line.match(/LV\s+Name/)
            name = line.match(/LV\s+Name\s+\/\w+\/\w+\/(.+)/).captures.first.to_s
          elsif line.match(/LV\s+Size/)
            size = line.match(/LV\s+Size\s+(\d+\.\d+)/).captures.first.to_s
            lv_data[name.to_sym] = size
          end
        end
        f.close
        lv_data
      end

      def df_for_image_path(image_path)
        raise "Image path #{image_path} does not exist" unless File.directory?(image_path)
        f = open("|df #{image_path}")
        line = f.readlines[1]
        match_data = line.match(/(.+)\s+(\d+)\s+(\d+)\s+(\d+)\s+\d+%\s+.+/).to_a
        match_data.shift(2)
        total, used, free = match_data
        f.close
        { :total => total.to_f.floor, :used => used.to_f.ceil, :free => free.to_f.floor }
      end

      def du_for_image(image)
        raise "Image #{image} does not exist" unless File.exists?(image)
        f = open("|du --apparent-size #{image}")
        line = f.readlines.first
        size = line.match(/^(\d+).+img$/).captures.first
        f.close
        size
      end

      def get_images_for_image_path(image_path)
        files = {}
        Dir.glob("#{image_path}/*.img").each do |file_path|
          name = File.basename(file_path, File.extname(file_path))
          files[name.to_sym] = du_for_image(file_path)
        end
        files
      end

      action "details" do
        config = YAML.load_file('/etc/provision/config.yaml')
        raise "Un-supported host vm_storage_type is #{config['vm_storage_type']}" unless config['vm_storage_type'] = 'new'
        storage = config['storage']
        raise "Storage key was not found in config.yaml" if storage.nil?
        storage.keys.sort.each do |storage_type|
          storage_type_arch = storage[storage_type]['arch']
          case storage_type_arch
          when 'LVM'
            reply[storage_type] = get_vg_data(storage[storage_type]['options']['vg'])
            reply[storage_type][:arch] = storage_type_arch
            reply[storage_type][:existing_storage] = get_lv_data_for_vg(storage[storage_type]['options']['vg'])
          when 'Image'
            reply[storage_type] = df_for_image_path(storage[storage_type]['options']['image_path'])
            reply[storage_type][:arch] = storage_type_arch
            reply[storage_type][:existing_storage] = get_images_for_image_path(storage[storage_type]['options']['image_path'])
          else
            raise "Unsure how to deal with architecture: #{arch}"
          end
        end
      end
    end
  end
end
