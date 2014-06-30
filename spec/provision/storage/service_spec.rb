require 'rspec'
require 'provision'
require 'provision/storage'
require 'provision/storage/service'

describe Provision::Storage::Service do
  class ExtendedStorageService < Provision::Storage::Service
    def get_storage_types
      @storage_types
    end
  end

  describe 'common' do

    before do
      @settings = {
        :os => {
          :arch    => 'LVM',
          :options => {
            :vg => 'main'
          }
        },
        :data => {
          :arch    => 'LVM',
          :options => {
            :vg => 'data'
          }
        }
      }

      @storage_service = Provision::Storage::Service.new(@settings)
    end

    it 'should set the default method to image for the root filesystem' do
      storage_service = ExtendedStorageService.new(@settings)
      storage_hash = {
        '/'.to_sym => {
          :type => 'os',
          :size => '10G',
        }
      }
      expected_root_settings = {
        :type => 'os',
        :size => '10G',
        :prepare => {
          :method => :image,
        },
      }

      storage = storage_service.get_storage(:os)
      storage.should_receive(:init_filesystem).with('root', expected_root_settings)
      storage_service.init_filesystems('root', storage_hash)
      storage.stub(:init_filesystem)

    end

  end
  describe 'LVM' do

    before do
      @settings = {
        :os => {
          :arch    => 'LVM',
          :options => {
            :vg => 'main'
          }
        },
        :data => {
          :arch    => 'LVM',
          :options => {
            :vg => 'data'
          }
        }
      }

      @storage_service = Provision::Storage::Service.new(@settings)
    end

    it 'should raise exception if provisioning an LVM without specifying a vg' do
      settings = {
        :os => { :arch    => 'LVM' }
      }
      expect {
        storage_service = Provision::Storage::Service.new(settings)
      }.to raise_error "Storage service requires each storage type to specify the 'options' setting"
    end


    it 'generates the correct XML to put into a libvirt template for a single storage setup' do
      storage_hash = {
        '/'.to_sym => {
          :type => 'os',
          :size => '10G',
        }
      }
      @storage_service.spec_to_xml('test', storage_hash).should eql( <<-EOS
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
          :size => '10G',
        },
        '/var/lib/mysql'.to_sym => {
          :type => 'data',
          :size => '100G',
        }
      }
      @storage_service.spec_to_xml('test', storage_hash).should eql( <<-EOS
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw'/>
      <source dev='/dev/main/test' />
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw'/>
      <source dev='/dev/data/test' />
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
          :arch    => 'Image',
        },
      }
      expect {
        @storage_service = Provision::Storage::Service.new(settings)
      }.to raise_error "Storage service requires each storage type to specify the 'options' setting"
    end

    it 'generates the correct XML to put into a libvirt template for a single storage setup' do
      storage_hash = {
        '/'.to_sym => {
          :type => 'os',
          :size => '10G',
        }
      }
      @storage_service.spec_to_xml('test', storage_hash).should eql( <<-EOS
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw'/>
      <source dev='#{@tmpdir}/os/test' />
      <target dev='vda' bus='virtio'/>
    </disk>
  EOS
      )
    end

    it 'generates the correct XML to put into a libvirt template for a multi storage setup' do
      storage_hash = {
        '/'.to_sym => {
          :type => 'os',
          :size => '10G',
        },
        '/var/lib/mysql'.to_sym => {
          :type => 'data',
          :size => '100G',
        }
      }
      @storage_service.spec_to_xml('test', storage_hash).should eql( <<-EOS
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw'/>
      <source dev='#{@tmpdir}/os/test' />
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw'/>
      <source dev='#{@tmpdir}/data/test' />
      <target dev='vdb' bus='virtio'/>
    </disk>
  EOS
      )
    end
  end
end
