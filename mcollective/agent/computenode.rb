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

      action 'archive_persistent_storage' do
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

        pid = ::Process.spawn("/usr/local/sbin/live-migrate-vm '#{vm_name}' '#{dest_host_fqdn}' 2>&1",
                              :pgroup => true,
                              :chdir => '/',
                              :in => :close,
                              :out => log_filename,
                              :err => :close)
        ::Process.detach(pid)

        File.write("/var/run/live_migration_#{vm_name}.pid", pid)

        status = get_live_migration_status(vm_name)
        status.each { |key, value| reply[key] = value }
      end

      action 'check_live_vm_migration' do
        status = get_live_migration_status(request[:vm_name])
        status.each { |key, value| reply[key] = value }
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

      def get_live_migration_status(vm_name)
        status = {}

        pid_filename = "/var/run/live_migration_#{vm_name}.pid"
        pid = File.exist?(pid_filename) ? File.read(pid_filename).to_i : -1

        log_filename = "/var/log/live_migration/#{vm_name}-current"
        log_file_content = []
        if File.exist?(log_filename)
          log_file_content = File.readlines(log_filename)
        end

        progress_percentages = log_file_content.map { |line| line.scan(/Migration: \[ (\d?\d?\d) %\]/) }.flatten
        status[:progress_percentage] = progress_percentages.empty? ? 0 : progress_percentages.last.to_i

        if pid_running?(pid)
          status[:state] = 'running'
          status[:domjobinfo] = `virsh domjobinfo #{vm_name} 2>&1`.split("\n").grep(/:/).map do |line|
            pair = line.gsub(/\s+/, ' ').split(':', 2).map(&:strip)
            [pair[0].gsub(' ', '_').downcase.to_sym, pair[1]]
          end.to_h
        else
          failed = log_file_content.grep(/MIGRATION SUCCESSFUL/).empty?
          status[:state] = failed ? 'failed' : 'successful'
        end
        status
      end

      def pid_running?(pid)
        ::Process.getpgid(pid)
        return true
      rescue Errno::ESRCH
        return false
      end
    end
  end
end
