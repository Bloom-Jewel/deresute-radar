=begin
  Rhythm.rb
  
  Basic Rhythm-related classes
=end

require_relative 'final_class'
require_relative 'kernel_snippet'
require_relative 'simple_hash_util'
require_relative 'method_redefine'

module Rhythm
  class Timing
    "Immutable Timing object"
    # module inclusion
    include Comparable
    include FinalClass
    
    # constants
    VALID_BASE_PRIME = [1,2,3].freeze()
    DEEPEST_POWER_2  = 4
    
    # class variables
    @@intern = {}
    
    # constructor
    def initialize(bar,frac=Rational(0,1))
      @bar = bar
      @frac = frac
    end
    
    # accessors
    public
    def bar
      return @bar
    end
    def dividend
      return @frac.numerator
    end
    def divisor
      return @frac.denominator
    end
    
    def +(shift)
      Timing(to_r + shift.to_r)
    end
    def -(shift)
      Timing(to_r - shift.to_r)
    end
    
    def <=>(other)
      to_r <=> other.to_r
    end
    
    # private methods
    private
    
    # protected methods
    protected
    
    # public methods
    public
    def eql?(other)
      
    end
    def inspect
      return sprintf("<Timing (%d:%d/%d)>",bar,dividend,divisor)
    end
    def to_s
      return sprintf("{%d,%d/%d}",bar,dividend,divisor)
    end
    def to_i
      return @bar
    end
    def to_r
      return @bar + @frac
    end
    def to_f
      return (@bar + @frac).to_f
    end
    def to_a
      return [bar,dividend,divisor]
    end
    
    # class methods
    class << self
      # private static methods
      private
      def round_to_valid(real_num,max_val=1<<DEEPEST_POWER_2)
        / Check Precision /
        rn = real_num
        b,dv,dd = 0,0,1
        eps = 1.0e-3
        harshpprox = false
        / Lambda Functions /
        approximation = proc { |  val  | val<=eps || val>=1-eps }
        remainder     = proc { |val, dn| ((val*dn)%1) }
        divisable     = proc { |val, dn| approximation.call(remainder.call(val,dn)) }
        b = rn.truncate()
        rn -= b
        / Find the dividend /
        loop do
          / Checks divisable by VALID_PRIME /
          break if VALID_BASE_PRIME.any? { |prim|
            dd  *= prim
            if(divisable.call(rn,dd)) then
              dv = (remainder.call(rn,1)*dd).round()
              true
            else
              dd  /= prim
              false
            end
          }
          / Fails to meet the requirement, advance the iteration by mult of 2 /
          dd  *= 2
          if(dd>max_val) then
            dv = (rn * dd).round()
            harshpprox = true
            break
          end
        end
        
        b+=1 if(rn>=1-eps)
        
        return Rational(b*dd+dv,dd)
      end
      
      unless private_method_defined?(:uncached_new)
        alias_method :uncached_new,:new
        private :uncached_new
      end
      
      # protected static methods
      protected
      
      # public static methods
      public
      def new(*args)
        bar  = args.first.is_a?(Integer)  ? args.shift() : 0;
        frac = args.first.is_a?(Timing) ? args.shift() : round_to_valid(
          args.first.is_a?(Rational) ? args.shift() : (
            args.first.is_a?(Numeric) && !args.first.is_a?(Integer) ?
              args.shift() : Rational(0,1)
            )
        )
        bar,frac = (frac+bar).divmod(1) unless frac.is_a?(Timing)
        mixed = Rational(frac+bar)
        
        @@intern[mixed] ||= uncached_new(bar,frac)
        return @@intern[mixed]
      end
    end
  end
  class BPMData
    "Immutable BPM Data"
    # module inclusion
    include Comparable
    include FinalClass
    
    # constants
    
    # class variables
    @@intern = {}
    
    # constructor
    def initialize(bpm=120.0,up_bar=4,down_bar=4)
      @bpm = bpm
      @bar = [up_bar,down_bar]
    end
    
    # accessors
    public
    def bpm
      return @bpm
    end
    def bar
      return @bar.dup
    end
    def up_bar
      return @bar.first
    end
    def down_bar
      return @bar.last
    end
    def sec
      return (60).fdiv(bpm)
    end
    def msec
      return 1000 * sec
    end
    
    # private methods
    private
    
    # protected methods
    protected
    
    # public methods
    public
    def timing_at(offset)
      case offset
      when Timing
      when Numeric
      end
    end
    
    def inspect
      return sprintf("<BPM (%d:%d/%d)>",bpm,up_bar,down_bar)
    end
    def to_s
      return sprintf("{%d,%d/%d}",bpm,up_bar,down_bar)
    end
    def to_r
      return Rational(up_bar,down_bar)
    end
    def to_f
      return bpm
    end
    def to_a
      return [bpm,up_bar,down_bar]
    end
    
    # class methods
    class << self
      # private static methods
      private
      
      unless private_method_defined?(:uncached_new)
        alias_method :uncached_new,:new
        private :uncached_new
      end
      
      # protected static methods
      protected
      
      # public static methods
      public
      # conv_sec(period)
      # tries to convert given `period` to `float`
      # returns nil if failed to convert
      # returns 
      def conv_sec(period,bar_up=4,bar_down=4)
        period = period.to_f rescue nil
        return period ? (60.0).fdiv(period) : nil
      end
      
      def new(*args)
        bpm, up_bar, down_bar = args
        
        bpm = ((bpm > 0 ? bpm.to_f : 120.0) rescue 120.0)
        up_bar,down_bar = [
          ([1,up_bar].max.to_i rescue 4),
          ([2,2**(Math.log2(down_bar).ceil)].max.to_i rescue 4)
        ]
        
        key = [bpm,up_bar,down_bar].join('|')
        if @@intern.has_key?(key) then
          return @@intern[key]
        else
          @@intern[key] = uncached_new(bpm,up_bar,down_bar)
        end
      end
    end
  end
  GlobalConstDeclare(self)
end
