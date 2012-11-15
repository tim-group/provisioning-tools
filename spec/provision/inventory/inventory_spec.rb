require 'provision/inventory'

describe Provision::Inventory do

  it 'generates a spec hash for a list of machine to be provisioned' do
    extend Provision::Inventory
    host "kvmc7", :spindles=>["s1","s2"] do
      env "se", :domain=>"net.local" do
        generator "selubuntu"  do
          template "precise-selenium"
          basename "selubuntu"
          range(1,2)
          selenium.sehub "segrid:7799"
          vm.ram 102400
          vm.interfaces [{:type=>"network",:name=>"provnat"}, {:type=>"bridge", :name => "br0"}]
          vm.cpus 1
        end
        generator "la" do
        end
      end
    end

    expected_specs = [
      {:env=>"se",:hostname=>"se-selubuntu-001", :sehub=>"segrid:7799", :ram=>102400, :template=>"precise-selenium",:cpus=>1,:interfaces=>[{:type=>"network",:name=>"provnat"}, {:type=>"bridge", :name => "br0"}], :spindle=>"s1", :domain=>"net.local"},
      {:env=>"se", :hostname=>"se-selubuntu-002", :sehub=>"segrid:7799", :ram=>102400, :template=>"precise-selenium",:cpus=>1,:interfaces=>[{:type=>"network",:name=>"provnat"}, {:type=>"bridge", :name => "br0"}], :spindle=>"s2",:domain=>"net.local"}
    ]
    get_host("kvmc7").get_env("se").get_generator("selubuntu").generate_specs.should eql(expected_specs)
  end

  it 'can provide an inventory'
  ## prov --host=kvmc7 --env=grid


  it 'can generate specs for all generators in an environment' do
    extend Provision::Inventory

    expected_specs = [
      {:env=>"se", :hostname=>"se-selubuntu-001", :sehub=>"segrid:7799", :ram=>102400, :template=>"precise-selenium",:cpus=>1,:interfaces=>[{:type=>"network",:name=>"provnat"}, {:type=>"bridge", :name => "br0"}], :spindle=>"s1", :domain=>"net.local"},
      {:env=>"se", :hostname=>"se-selubuntu-002", :sehub=>"segrid:7799", :ram=>102400, :template=>"precise-selenium",:cpus=>1,:interfaces=>[{:type=>"network",:name=>"provnat"}, {:type=>"bridge", :name => "br0"}], :spindle=>"s2",:domain=>"net.local"}
    ]

    host "kvmc7", :spindles=>["s1","s2"] do
      env "se", :domain=>"net.local" do
        generator "selubuntu"  do
          template "precise-selenium"
          basename "selubuntu"
          range(1,2)
          selenium.sehub "segrid:7799"
          vm.ram 102400
          vm.interfaces [{:type=>"network",:name=>"provnat"}, {:type=>"bridge", :name => "br0"}]
          vm.cpus 1
        end
      end
    end
    get_host("kvmc7").get_env("se").get_generator("*").generate_specs.should eql(expected_specs)
  end

  it 'can print the structure to explore the inventory' do
    extend Provision::Inventory
    host "hostx" do
    end
    get_hosts().size().should eql(1)
  end

end
