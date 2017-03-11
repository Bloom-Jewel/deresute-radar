=begin
  SimpleHashUtil.rb

  a module that specifies the way object hashing method should be performed
=end

require_relative 'kernel_snippet'
require_relative 'method_redefine'

class Object
  redefine :hash do |shu_old_hash|
    hsh = shu_old_hash.call
    if self.instance_variables.empty? then
    else
      self.instance_variables.each { |vk|
        vr  = self.instance_variable_get(vk)
        hsh = ((hsh << 13) ^ vr.hash) % (1 << ((0).size << 3))
      }
    end
    hsh
  end
end

