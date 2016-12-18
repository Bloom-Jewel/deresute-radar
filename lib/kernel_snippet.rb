=begin
  KernelSnippet.rb
  
  activate the snippet of Kernel if you want
  to have a shortened declaration without using ::new
=end

def GlobalConstDeclare(mod)
  fail TypeError,sprintf("`%s`(%s) is not a module!",
    mod.inspect,mod.class) unless mod.is_a?(Module)
  Kernel.module_exec {
    # Recursively reduces the namespace required if possible
    setGlobalConst = proc { |context, constLimit=nil|
      context.constants.each { |constData|
        constRef = context.const_get(constData)
        if((constLimit.nil? || constLimit > 1) && constRef.is_a?(Module)) then
          unless Kernel.const_defined?(constData)
            if constRef.is_a?(Class)
              self.send(:define_method, constData) { |*args|
                constRef.new(*args)
              }
            end
            Kernel.const_set(constData,constRef)
          end
          setGlobalConst.call(constRef,constLimit && (constLimit-1))
        end
      };
    };

    setGlobalConst.call(mod,nil)
  }
end
