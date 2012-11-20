module MCollective
    module Agent
        class Aptupdate<RPC::Agent
            action 'update' do
              out = ""
              command = "git pull --rebase"
              path = "/etc/puppet"
              run "cd /var/www/apt.*/ubuntu && #{command} 2>&1", :stderr => :err, :stdout => out, :chomp => true

              unless out == ""
                reply[:output] = out
              else
                reply[:output] = "No action needed"
              end
            end
        end
    end
end
