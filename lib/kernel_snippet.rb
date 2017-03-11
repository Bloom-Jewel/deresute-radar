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
    set_global_const = proc { |context, const_limit=nil|
      # puts [context,*constants(false)].to_s
      context.constants(false).each { |const_data|
        const_ref = context.const_get(const_data)
        next if context == const_data
        if((const_limit.nil? || const_limit > 1) && const_ref.is_a?(Module)) then
          unless Kernel.const_defined?(const_data)
            if const_ref.is_a?(Class)
              self.send(:define_method, const_data) { |*args|
                const_ref.new(*args)
              }
            end
            Kernel.const_set(const_data,const_ref)
          end
          set_global_const.call(const_ref,const_limit && (const_limit-1))
        end
      }
    }
    set_global_const.call(mod,nil)
  }
end
