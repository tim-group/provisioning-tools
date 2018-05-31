module MCollective
  module Agent
    class Computenode < RPC::Agent
      action 'launch' do
        implemented_by 'actions.rb'
      end

      action 'clean' do
        implemented_by 'actions.rb'
      end

      action 'allocate_ips' do
        implemented_by 'actions.rb'
      end

      action 'free_ips' do
        implemented_by 'actions.rb'
      end

      action 'add_cnames' do
        implemented_by 'actions.rb'
      end

      action 'remove_cnames' do
        implemented_by 'actions.rb'
      end

      action 'check_definition' do
        implemented_by 'actions.rb'
      end

      action 'create_storage' do
        implemented_by 'actions.rb'
      end

      action 'enable_live_migration' do
        manage_live_migration(request[:direction] == 'inbound', request[:other_host], true)
      end

      action 'disable_live_migration' do
        manage_live_migration(request[:direction] == 'inbound', request[:other_host], false)
      end

      action 'live_migrate_vm' do
        vm_name = request[:vm_name]
        dest_host_fqdn = request[:other_host]
        puts "LIBVIRT_DEBUG=2 "\
             "virsh migrate --live --verbose --copy-storage-all --persistent --change-protection #{vm_name} #{dest_host_fqdn}"
      end

      private

      def manage_live_migration(inbound, host, enable)
        factfile = '/etc/facts.d/live_migration.fact'
        factname = inbound ? 'incoming_live_migration_sources' : 'outgoing_live_migration_destinations'

        facts = {}
        File.read(factfile).split("\n").each do |line|
          fact = line.split('=')
          facts[fact[0].strip] = fact[1].strip
        end if File.exists? factfile

        current = facts.fetch(factname, '').split(',')
        if enable
          current.push(host) unless current.include?(host)
        else
          current.delete(host)
        end
        facts[factname] = current.join(',')
        facts.delete(factname) if current.empty?

        File.open(factfile, 'w') do |outfile|
          facts.each { |name, value| outfile.puts "#{name}=#{value}" }
        end
      end
    end
  end
end
