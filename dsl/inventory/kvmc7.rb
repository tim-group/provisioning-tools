host "kvmc7", :spindles=>["s1","s2"] do
  generator "selubuntu"  do
    template "selenium"
    basename "ldn-selubuntu"
    range(1,5)
    selenium.sehub "segrid:7799"
  end
end