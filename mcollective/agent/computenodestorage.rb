require 'yaml'
require 'pp'

module MCollective
  module Agent
    class Computenodestorage<RPC::Agent
      metadata    :name        => "SimpleRPC Agent For retrieving VG details",
                  :description => "Agent to query VG details via MCollective",
                  :author      => "Gary R",
                  :license     => "MIT",
                  :url         => "http://timgroup.com",
                  :version     => "1.0",
                  :timeout     => 10


      action "details" do
        config = YAML.load_file('/etc/provision/config.yaml')
        raise "Un-supported host vm_storage_type is #{config['vm_storage_type']}" unless config['vm_storage_type']='new'
        storage = config['storage']
        raise "Storage key was not found in config.yaml" if storage.nil?
        storage.keys.sort.each do |storage_type|
          storage_type_arch = storage[storage_type]['arch']

          case storage_type_arch
          when 'LVM'
            total = 0
            used = 0
            free = 0
            volume_group = storage[storage_type]['options']['vg']
            f = open("|vgdisplay #{volume_group} --units g")
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
            reply[storage_type] = { :total => total.to_f.floor, :used => used.to_f.ceil, :free => free.to_f.floor, :arch => storage_type_arch}
          when 'Image'
            image_path = storage[storage_type]['options']['image_path']
            raise "Image path #{image_path} does not exist" unless File.directory?(image_path)
             f = open("|df #{image_path}")
             line = f.readlines[1]
             match_data = line.match(/(.+)\s+(\d+)\s+(\d+)\s+(\d+)\s+\d+%\s+.+/).to_a
             match_data.shift(2)
             total, used, free = match_data
             m = { :total => total.to_f, :used => used.to_f, :free => free.to_f, :arch => storage_type_arch }
             reply[storage_type] = m.each.inject({}) do |result, (key, value)|
              if (key == :arch)
                result[key] = value
              elsif key == :used
                result[key] = ((value.to_f / (1024*1024) * 100).round / 100.0).to_f.ceil
              else
                result[key] = ((value.to_f / (1024*1024) * 100).round / 100.0).to_f.floor
              end
              result
             end

             f.close
          else
            raise "Unsure how to deal with architecture: #{arch}"
          end
        end
      end
    end
  end
end
