=begin
  FinalClass.rb
  
  defines an interface that disallows class inheritance
=end

# http://stackoverflow.com/questions/10692961/inheriting-class-methods-from-mixins
module FinalClass
  def self.included(cls)
    cls.class_eval { |c|
      def self.inherited(child)
        if child.name then
          # Prevention for non-anonymous class
          name = child.name
          ctx  = name.split('::')
          ctg  = ctx.last()
          ctx.unshift(Object)
          # Perform iterative namespace checking
          begin
            nctx = ctx.shift()
            mctx = nctx.send(:const_get,ctx.shift())
            if(ctx.empty?) then
              nctx.send(:remove_const,ctg)
            else
              ctx.unshift(mctx)
            end
          end until ctx.empty?
        end
        fail ScriptError,sprintf("Cannot derive class %s to %s",self,
          child.name ? child : '(anonymous class)')
      end
    }
  end
end
