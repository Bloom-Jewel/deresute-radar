=begin
  Typed_Array.rb
  
  Create typed array structure
=end

require_relative 'kernel_snippet'

# INCLUSION LINE STARTS HERE
class TypedArray
  "An array wrapper that limits the object sets"
  include Enumerable
  
#  def method_missing(met,*args,&block)
#    if @data.respond_to? met then
#      self.class.send :define_method,met do |*args|
#        @data.public_send met,*args
#      end
#      public_send met,*args
#    else
#      super(met,*args,&block)
#    end
#  end
  
  class << self
    # one time only
    private
    def build(base_class:[],direct_class:[],index_strict:false,size:0..Float::INFINITY)
      # sanity check #base, #direct
      [
        ['base class',base_class],
        ['direct class',direct_class]
      ].each do |(name, classes)|
        fail TypeError, "Expecting #{name} is array, but #{classes.class}" unless classes.instance_of? Array
        fail TypeError, "Expecting list of class on #{name}, given #{classes.map(&:class).inspect}" unless classes.all? { |cls| cls.is_a? Class }
      end
      fail ArgumentError, "Cannot build a class of no type" if [base_class,direct_class].all?(&:empty?)
      
      index_strict = !!index_strict
      
      # sanity check #size
      case size
      when Integer
        size = Range.new 0,size
      when Array
        size = Range.new *size
      when Range
        # do nothing
      else
        size = Range.new 0,Float::INFINITY
      end
      
      fail RangeError, "Cannot pass negative value on lower size bound" if size.begin < 0
      
      base_class.freeze
      direct_class.freeze
      size.freeze
      
      type_checker = proc do |array|
        class_base = nil
        class_dire = nil
        
        mistype = proc do |item|
          ignbase = class_base.nil? || (class_base.is_a?(Array) && class_base.empty?)
          igndire = class_dire.nil? || (class_dire.is_a?(Array) && class_dire.empty?)
          misbase = class_base && (class_base.is_a?(Array) ?
            (class_base.empty? ? false : !class_base.any? { |cls| item.is_a? cls }) :
            (!item.is_a? class_base))
          misdire = class_dire && (class_dire.is_a?(Array) ?
            (class_dire.empty? ? false : !class_dire.any? { |cls| item.instance_of? cls }) :
            (!item.instance_of? class_dire))
          if ((misbase||ignbase) && (misdire||igndire)) then
            fail TypeError,
              sprintf(
                "Expected %s, but given %s instead",
                [
                  misbase ? (
                    class_base.is_a?(Array) ? 
                      sprintf("any class based off %s",class_base * ',') :
                      sprintf("%s and it's descendant",class_base)
                  ) : "",
                  misdire ? (
                    class_dire.is_a?(Array) ?
                      sprintf("direct-class of %s",class_dire * ',') :
                      sprintf("%s itself",class_dire)
                  ) : "",
                ].select{|str| !str.empty? }.join(' or '),
                item.class
              )
          end
        end
        
        if index_strict then
          array.each_with_index do |item,index|
            # Perform looping index-based type checker
            class_base = base_class[index % base_class.size] rescue nil
            class_dire = direct_class[index % direct_class.size] rescue nil
            
            mistype.call item
          end
        else
          # Perform non-index class based type-checker
          class_base = base_class
          class_dire = direct_class
          
          array.each do |item|
            mistype.call item
          end
        end
        array
      end
      
      limit_checker = proc do |array|
        min,max = size.first, size.last
        fail RangeError, sprintf("Invalid composition for array, length at %d outside range of %.0f..%.0f",
          array.size,min,max) if !array.size.between?(min,max)
      end
      
      define_method :initialize do |*data|
        @data = []
        begin
          type_checker.call  data
          limit_checker.call data
          @data.concat data
        rescue Exception => e
          if $DEBUG then
            $stderr.puts "initializing empty array, #{e.class}: #{e.message}"
          else
            raise e
          end
        end
      end
      
      define_method :[] do |*keys|
        case keys.length
        when 0
          @data.each_with_index
        when 1
          @data[keys.first]
        else
          @data.values_at *keys
        end
      end
      
      define_method :[]= do |key,value|
        fail TypeError, sprintf("Expected Integer key given %s",
          key.class) unless key.is_a?(Integer)
        
        allowed_range = Range.new(*([(~@data.size).succ,@data.size].sort));
        fail RangeError, sprintf("Index given out of bound, given %d expected %s",
          key,allowed_range) if allowed_range.include?(key)
        
        out_range = key == allowed_range.end
        old_value = @data[key]
        begin
          @data[key] = value
          type_checker.call @data
          limit_checker.call @data
        rescue Exception => e
          if out_range
            @data.pop
          else
            @data[key] = old_value
          end
          if $DEBUG then
            $stderr.puts "reverting change; #{e.class}: #{e.message}"
          else
            raise e
          end
        end
        @data[key]
      end
      
      define_method :start do @data.first end
      define_method :end do @data.last end
      define_method :size do @data.size end
      define_method :length do @data.length end
      define_method :empty? do @data.empty? end
      define_method :each do |&block| @data.each(&block) end
      
      [[:push,:pop],[:unshift,:shift]].each do |(mis, mrm)|
        define_method mis do |*items|
          begin
            @data.send mis, *items
            type_checker.call  @data
            limit_checker.call @data
          rescue Exception => e
            @data.send mrm, items.length
            if $DEBUG then
              $stderr.puts "reverting change; #{e.class}: #{e.message}"
            else
              raise e
            end
          else
            self
          end
        end
        
        define_method mrm do |amount|
          begin
            items = @data.send mrm, amount
            type_checker.call  @data
            limit_checker.call @data
          rescue Exception => e
            @data.send mis, *items
            if $DEBUG then
              $stderr.puts "reverting change; #{e.class}: #{e.message}"
            else
              raise e
            end
          else
            items
          end
        end
      end
      
      define_method :inspect do
        "#<%s:%#016x %s>" % [
          self.class,
          self.__id__,
          @data
        ]
      end
      define_method :to_s do
        @data.to_s
      end
      
      # Run once
      if method(:build).owner != self.singleton_class
        self.singleton_class.instance_exec do 
          undef_method :build
          public :new
        end
      end
    end
    
    private :new
  end
  
  GlobalConstDeclare(self)
end

# INCLUSION LINE ENDS HERE

if __FILE__ == $0 then
  puts("Loaded main module.")
end
