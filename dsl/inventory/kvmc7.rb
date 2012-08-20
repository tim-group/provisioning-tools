host "kvmc7", :spindles=>["s1","s2"] do
  env "se", :domain=>"net.local" do
    generator "browser"  do
      template "selenium"
      basename "browser"
      range(1,5)
      selenium.sehub "segrid:7799"
    end
  end
end
