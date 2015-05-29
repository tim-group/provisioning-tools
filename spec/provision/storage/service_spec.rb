require 'provisioning-tools/provision'
require 'provisioning-tools/provision/storage'
require 'provisioning-tools/provision/storage/service'

describe Provision::Storage::Service do
  describe 'common' do
    before do
      @settings = {
        :os => {
          :arch    => 'LVM',
          :options => { :vg => 'main' }
        },
        :data => {
          :arch    => 'LVM',
          :options => { :vg => 'data' }
        }
      }

      @storage_service = Provision::Storage::Service.new(@settings)
    end
  end
  describe 'LVM' do
    before do
      @settings = {
        :os => {
          :arch    => 'LVM',
          :options => { :vg => 'main' }
        },
        :data => {
          :arch    => 'LVM',
          :options => { :vg => 'data' }
        }
      }

      @storage_service = Provision::Storage::Service.new(@settings)
    end

    it 'should raise exception if provisioning an LVM without specifying a vg' do
      settings = {
        :os => { :arch    => 'LVM' }
      }
      expect do
        storage_service = Provision::Storage::Service.new(settings)
      end.to raise_error "Storage service requires each storage type to specify the 'options' setting"
    end

    it 'generates the correct XML to put into a libvirt template for a single storage setup' do
      storage_hash = {
        '/'.to_sym => {
          :type => 'os',
          :size => '10G'
        }
      }
      @storage_service.create_config('test', storage_hash)
      @storage_service.spec_to_xml('test').should eql(<<-EOS
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw'/>
      <source dev='/dev/main/test' />
      <target dev='vda' bus='virtio'/>
    </disk>
  EOS
                                                     )
    end

    it 'generates the correct XML to put into a libvirt template for a multi storage setup' do
      storage_hash = {
        '/'.to_sym => {
          :type => 'os',
          :size => '10G'
        },
        '/var/lib/mysql'.to_sym => {
          :type => 'data',
          :size => '100G'
        }
      }
      @storage_service.create_config('test', storage_hash)
      @storage_service.spec_to_xml('test').should eql(<<-EOS
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw'/>
      <source dev='/dev/main/test' />
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw'/>
      <source dev='/dev/data/test_var_lib_mysql' />
      <target dev='vdb' bus='virtio'/>
    </disk>
  EOS
                                                     )
    end
  end

  describe 'image' do
    before do
      @tmpdir = Dir.mktmpdir
      FileUtils.mkdir "#{@tmpdir}/os"
      FileUtils.mkdir "#{@tmpdir}/data"

      @settings = {
        :os => {
          :arch    => 'Image',
          :options => {
            :image_path => "#{@tmpdir}/os"
          }
        },
        :data => {
          :arch    => 'Image',
          :options => {
            :image_path => "#{@tmpdir}/data"
          }
        }
      }

      @storage_service = Provision::Storage::Service.new(@settings)
    end

    after do
      FileUtils.remove_entry_secure "#{@tmpdir}/os"
      FileUtils.remove_entry_secure "#{@tmpdir}/data"
      FileUtils.remove_entry_secure @tmpdir
    end

    it 'should raise exception if provisioning an Image without an image_path' do
      settings = {
        :os => {
          :arch    => 'Image'
        }
      }
      expect do
        @storage_service = Provision::Storage::Service.new(settings)
      end.to raise_error "Storage service requires each storage type to specify the 'options' setting"
    end

    it 'should not remove persistent storage' do
      FileUtils.touch "#{@tmpdir}/os/oy-db-001.img"
      FileUtils.touch "#{@tmpdir}/data/oy-db-001_var_lib_mysql.img"
      File.exist?("#{@tmpdir}/os/oy-db-001.img").should eql true
      File.exist?("#{@tmpdir}/data/oy-db-001_var_lib_mysql.img").should eql true

      @storage_service = Provision::Storage::Service.new(@settings)
      storage_hash = {
        '/'.to_sym => {
          :type => 'os',
          :size => '10G'
        },
        '/var/lib/mysql'.to_sym => {
          :type       => 'data',
          :size       => '10G',
          :persistent => true
        }
      }
      @storage_service.create_config('oy-db-001', storage_hash)
      @storage_service.remove_storage('oy-db-001')
      File.exist?("#{@tmpdir}/os/oy-db-001.img").should eql false
      File.exist?("#{@tmpdir}/data/oy-db-001_var_lib_mysql.img").should eql true
    end

    it 'should check persistent storage on creation' do
      storage_hash = {
        '/'.to_sym => {
          :type => 'os',
          :size => '10G'
        },
        '/var/lib/mysql'.to_sym => {
          :type       => 'data',
          :size       => '10G',
          :persistent => true
        }
      }
      FileUtils.touch "#{@tmpdir}/data/oy-db-001_var_lib_mysql.img"
      File.exist?("#{@tmpdir}/data/oy-db-001_var_lib_mysql.img").should eql true

      @storage_service = Provision::Storage::Service.new(@settings)
      @storage_service.create_config('oy-db-001', storage_hash)
      mount_point_obj = @storage_service.get_mount_point('oy-db-001', '/var/lib/mysql'.to_sym)
      storage = @storage_service.get_storage(:data)
      storage.should_receive(:check_persistent_storage).with('oy-db-001', mount_point_obj)
      @storage_service.create_storage('oy-db-001')
    end

    it 'should not call init_filesystems for persistent storage' do
      @storage_service = Provision::Storage::Service.new(@settings)
      storage_hash = {
        '/var/lib/mysql'.to_sym => {
          :type       => 'data',
          :size       => '10G',
          :persistent => true
        }
      }
      @storage_service.create_config('oy-db-001', storage_hash)
      storage = @storage_service.get_storage(:data)
      storage.stub(:init_filesystem)
      storage.should_not_receive(:init_filesystem)
      @storage_service.init_filesystems('oy-db-001')
    end

    it 'generates the correct XML to put into a libvirt template for a single storage setup' do
      storage_hash = {
        '/'.to_sym => {
          :type => 'os',
          :size => '10G'
        }
      }
      @storage_service.create_config('test', storage_hash)
      @storage_service.spec_to_xml('test').should eql(<<-EOS
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw'/>
      <source dev='#{@tmpdir}/os/test.img' />
      <target dev='vda' bus='virtio'/>
    </disk>
  EOS
                                                     )
    end

    it 'generates the correct XML to put into a libvirt template for a multi storage setup' do
      storage_hash = {
        '/'.to_sym => {
          :type => 'os',
          :size => '10G'
        },
        '/var/lib/mysql'.to_sym => {
          :type => 'data',
          :size => '100G'
        }
      }
      @storage_service.create_config('test', storage_hash)
      @storage_service.spec_to_xml('test').should eql(<<-EOS
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw'/>
      <source dev='#{@tmpdir}/os/test.img' />
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw'/>
      <source dev='#{@tmpdir}/data/test_var_lib_mysql.img' />
      <target dev='vdb' bus='virtio'/>
    </disk>
  EOS
                                                     )
    end
  end
end
