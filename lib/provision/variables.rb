module Provision::Variables
  def make_var(method_name)
    inst_variable_name = "@#{method_name}".to_sym
    
    self.clas
    
#    define_method method_name do
#      instance_variable_get inst_variable_name
#    end
#    define_method "#{method_name}=" do |new_value|
#      instance_variable_set inst_variable_name, new_value
#    end
  end

end