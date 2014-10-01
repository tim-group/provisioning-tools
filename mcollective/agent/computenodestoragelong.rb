require 'provision'
require 'provision/storage'
require 'provision/storage/service'

module MCollective
  module Agent
    class Computenodestoragelong<RPC::Agent
      def copy(source, transport, transport_options)
        config = Provision::Config.new.get()
        storage_service = Provision::Storage::Service.new(config[:storage])
        name, type, path = source.split(':')
        path = '/' if path.nil?
        storage_service.copy(name, type, path, transport, transport_options)
      end

      action "copy" do
        source = request[:source]
        transport = request[:transport]
        transport_options = request[:transport_options]
        data
        begin
          reply.data = copy(source, transport, transport_options)
        rescue Provision::Storage::StorageNotFoundError
          reply.data = "Storage: #{source} does not exist here"
        end
      end
    end
  end
end
