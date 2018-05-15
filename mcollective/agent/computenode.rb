module MCollective
  module Agent
    class Computenode < RPC::Agent
      action 'launch' do
        implemented_by 'actions.rb'
      end

      action 'clean' do
        implemented_by 'actions.rb'
      end

      action 'hello' do
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
    end
  end
end
