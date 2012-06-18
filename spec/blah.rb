require 'yaml'

block = lambda {print a}

options = {:a=>"55"}
yaml = YAML::dump(options)
print block.binding.eval("a=YAML::load('#{yaml}')")

print block.binding.eval("a").to_yaml
