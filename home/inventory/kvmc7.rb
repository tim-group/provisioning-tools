host "kvmc7", :spindles=>["/mnt"] do
  env "bse", :domain=>"bos.net.local" do
    generator "se"  do
      template "selenium"
      basename "browser"
      range(1,5)
      selenium.sehub "bossegrid:7799"
    end
  end
end