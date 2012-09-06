host "test", :spindles=>["/mnt"] do
  env "local", :domain=>"bos.net.local" do
    generator "pm"  do
      template "puppetmaster"
      basename "puppetmaster"
      range(1,1)
    end
  end
end
