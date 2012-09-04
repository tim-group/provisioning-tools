host "test", :spindles=>["/mnt"] do
  env "local", :domain=>"bos.net.local" do
    generator "pm"  do
      template "puppetmaster"
      basename "puppetmaster"
      range(1,2)
    end
  end
end

host "localhost", :spindles=>["/mnt"] do
  env "local", :domain=>"bos.net.local" do
    generator "pm"  do
      template "puppetmaster"
      basename "puppetmaster"
      range(1,1)
      selenium.sehub "bossegrid:7799"
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
