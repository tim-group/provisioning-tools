require 'provision/inventory'

describe Provision::Inventory do

  it 'generates a spec hash for a list of machine to be provisioned' do
    extend Provision::Inventory
    host "kvmc7", :spindles=>["s1","s2"] do
      env "se", :domain=>"net.local" do
        generator "selubuntu"  do
          template "precise-selenium"
          basename "selubuntu"
          range(1,5)
          selenium.sehub "segrid:7799"
          vm.ram 102400
          vm.interfaces [:network=>"provnat", :bridge => "br0"]
          vm.cpus 1
        end
      end
    end

    expected_specs = [
      {:hostname=>"se-selubuntu-001", :sehub=>"segrid:7799", :ram=>102400, :template=>"precise-selenium",:cpus=>1, :interfaces=>[:network=>"provnat", :bridge=>"br0"], :spindle=>"s1", :domain=>"net.local"},
      {:hostname=>"se-selubuntu-002", :sehub=>"segrid:7799", :ram=>102400, :template=>"precise-selenium",:cpus=>1, :interfaces=>[:network=>"provnat", :bridge=>"br0"], :spindle=>"s2",:domain=>"net.local"},
      {:hostname=>"se-selubuntu-003", :sehub=>"segrid:7799", :ram=>102400, :template=>"precise-selenium",:cpus=>1, :interfaces=>[:network=>"provnat", :bridge=>"br0"], :spindle=>"s1",:domain=>"net.local"},
      {:hostname=>"se-selubuntu-004", :sehub=>"segrid:7799", :ram=>102400, :template=>"precise-selenium",:cpus=>1, :interfaces=>[:network=>"provnat", :bridge=>"br0"], :spindle=>"s2",:domain=>"net.local"},
      {:hostname=>"se-selubuntu-005", :sehub=>"segrid:7799", :ram=>102400, :template=>"precise-selenium",:cpus=>1, :interfaces=>[:network=>"provnat", :bridge=>"br0"], :spindle=>"s1",:domain=>"net.local"},
    ]
    get_host("kvmc7").get_env("se").get_generator("selubuntu").generate_specs.should eql(expected_specs)
  end

  it 'can provide an inventory'
## prov --host=kvmc7 --env=grid 

  it ''

end
