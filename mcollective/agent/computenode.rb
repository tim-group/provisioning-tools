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
        logdir = '/var/log/live_migration'

        require 'time'
        log_filename = "#{logdir}/#{vm_name}-#{Time.now.utc.iso8601}"

        require 'fileutils'
        FileUtils.mkdir_p logdir, :mode => 0755
        FileUtils.ln_sf log_filename, "#{logdir}/#{vm_name}-current"

        pid = ::Process.spawn("/usr/local/sbin/live-migrate-vm '#{vm_name}' '#{dest_host_fqdn}'",
                              :pgroup => true,
                              :chdir => '/',
                              :in => :close,
                              :out => log_filename,
                              :err => :out)
        ::Process.detach(pid)

        File.write("/var/run/live_migration_#{vm_name}.pid", pid)

        reply[:state] = pid_running?(pid) ? 'running' : 'failed'
      end

      action 'check_live_vm_migration' do
        vm_name = request[:vm_name]

        pid_filename = "/var/run/live_migration_#{vm_name}.pid"
        pid = File.exist?(pid_filename) ? File.read(pid_filename).to_i : -1

        if pid_running?(pid)
          reply[:state] = 'running'
          # virsh domjobinfo #{vm_name}
        else
          log_filename = "/var/log/live_migration/#{vm_name}-current"
          successful = File.exist?(log_filename) && !File.readlines(log_filename).grep(/MIGRATION SUCCESSFUL/).empty?
          reply[:state] = successful ? 'successful' : 'failed'
        end
      end

      private

      def manage_live_migration(inbound, host, enable)
        factfile = '/etc/facts.d/live_migration.fact'
        factname = inbound ? 'incoming_live_migration_sources' : 'outgoing_live_migration_destinations'

        facts = {}
        File.read(factfile).split("\n").each do |line|
          fact = line.split('=')
          facts[fact[0].strip] = fact[1].strip
        end if File.exist? factfile

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

      def pid_running?(pid)
        begin
          ::Process.getpgid( pid )
          return 0
        rescue Errno::ESRCH
          return 1
        end
      end
    end
  end
end
