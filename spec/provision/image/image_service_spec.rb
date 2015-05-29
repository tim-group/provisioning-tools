require 'provisioning-tools/provision/image/service'
require 'provisioning-tools/provision/image/catalogue'
require 'tempfile'

describe Provision::Image::Service  do
  before do
    @image_file = Tempfile.new('image')
  end

  after do
    @image_file.unlink
  end

  it 'does not remove image if spec has disallow_destroy set' do
    Provision::Image::Catalogue.stub :loadconfig
    config = { :vm_storage_type => 'image' }
    spec = { :disallow_destroy => 'true', :image_path => @image_file.path }
    image_service = Provision::Image::Service.new(:configdir => 'whatever', :config => config)

    expect do
      image_service.remove_image(spec)
    end.to raise_error("VM marked as non-destroyable")

    File.exist?(@image_file.path).should eql(true)
  end

  it 'remove image if spec does not have disallow_destroy set' do
    Provision::Image::Catalogue.stub :loadconfig
    config = { :vm_storage_type => 'image' }
    spec = { :image_path => @image_file.path }
    image_service = Provision::Image::Service.new(:configdir => 'whatever', :config => config)

    image_service.remove_image(spec)
    File.exist?(@image_file.path).should eql(false)
  end
end
