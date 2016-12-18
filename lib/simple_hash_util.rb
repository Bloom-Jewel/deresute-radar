=begin
  SimpleHashUtil.rb

  a module that specifies the way object hashing method should be performed
=end

require_relative 'kernel_snippet'

class Object
  alias :shu_oldHash :hash
  def hash
    hsh = shu_oldHash
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

