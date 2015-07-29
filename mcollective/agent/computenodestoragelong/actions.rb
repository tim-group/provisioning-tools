#!/opt/ruby-bundle/bin/ruby

require 'json'

$: << '/opt/provisioning-tools/lib/ruby/site_ruby'
require 'provisioning-tools/provision'
require 'provisioning-tools/provision/storage'
require 'provisioning-tools/provision/storage/service'

def copy(source, transport, transport_options)
  config = Provision::Config.new.get
  storage_service = Provision::Storage::Service.new(config[:storage])
  name, type, path = source.split(':')
  path = '/' if path.nil?
  storage_service.copy(name, type, path, transport, transport_options)
end

mco_args  = JSON.parse(File.read(ARGV[0]), :symbolize_names => true)
mco_reply = {}

mco_reply[:msg] = case mco_args[:action]
                  when 'copy'
                    source = mco_args[:data][:source]
                    transport = mco_args[:data][:transport]
                    transport_options = mco_args[:data][:transport_options]

                    begin
                      copy(source, transport, transport_options)
                    rescue Provision::Storage::StorageNotFoundError
                      "Storage: #{source} does not exist here"
                    end
                  end

File.open(ARGV[1], 'w') do |f|
  f.write(mco_reply.to_json)
end
