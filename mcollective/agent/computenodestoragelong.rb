module MCollective
  module Agent
    class Computenodestoragelong < RPC::Agent
      action 'copy' do
        implemented_by 'actions.rb'
      end
    end
  end
end
