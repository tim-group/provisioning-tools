host "localhost", :spindles=>["/mnt"] do
  env "dev", :domain=>"dev.net.local" do
    generator "pm"  do
      template "puppetmaster"
      basename "puppetmaster"
      range(1,1)
    end

#    generator "lb"  do
#      template "puppetclient"
#      basename "lb"
#      range(1,1)
#    end

    generator "refapp"  do
      template "puppetclient"
      basename "refapp"
      range(1,2)
    end
  end
end

host "kvmc7", :spindles=>["/mnt"] do
  env "bse", :domain=>"bos.net.local" do
    generator "se"  do
      template "selenium"
      basename "browser"
      range(1,5)
      selenium.sehub "ldn-dev-dellis.youdevise.com:7799"
    end
  end
end
