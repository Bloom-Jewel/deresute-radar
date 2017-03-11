=begin
  MethodRedefine.rb

  a module that allows method redefinition
=end

class Module
  def redefine(old_name,&block)
    old_method = instance_method(old_name)        
    define_method old_name do |*args|
      bound_method = old_method.bind self
      block.call bound_method,*args
    end
  end
  private :redefine
end
