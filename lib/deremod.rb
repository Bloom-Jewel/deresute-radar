=begin
  DereMod.rb
  
  Starlight Stage Note Composition Breakdown
=end

require_relative 'raw_json'
require_relative 'rhythm'
require_relative 'kernel_snippet'

# INCLUSION LINE STARTS HERE
module Deresute
  class ImportedSong < RawJSON
  end
  class ImportedChart < RawJSON
    
  end
  
  class Song
  end
  class BasicChart
    # constructor
    def initialize(build_data)
      fail TypeError, "Expected builder class!" unless ObjectSpace.each_object(ChartBuilder).to_a.include?(build_data)
      build_data.instance_exec do
        set :diff    , get_property :difficulty
        set :notes   , get_notes
        set :slides  , get_slides
        set :timeline, get_patterns
      end
    end
    
    # accessors
    
    # private methods
    private
    def get(var)
      instance_variable_get(:"@#{var}")
    end
    
    def set(var,val)
      instance_variable_set(:"@#{var}",val)
    end
    
    # protected methods
    protected
    
    # public methods
    public
    def each_notes
      @notes.each
    end
    def each_slides
      @slides.each
    end
    
    # class methods
    class << self
      # private static methods
      private
      
      # protected static methods
      protected
      
      # public static methods
      public
    end
  end
  class Chart < BasicChart
  end
  
  class ChartBuilder < BasicObject
    'Builder based class are formed through DSL'
    'Structure priority'
    '- Pair'
    '- Hold'
    '- Slide'
    '- Tap'
    # constructor
    def initialize
      @options = {}
      @notes = {}
      @slides = {}
      @pattern = []
    end
    
    # accessors
    
    # private methods
    private
    def get_property(key)
      @options[key]
    end
    
    def get_notes
      @notes
    end
    
    def get_slides
      @slides
    end
    
    def get_patterns
      @pattern
    end
    
    def set_property(key,val)
      @options.store(key,val)
    end
    
    def define_note(id:,at:,pos1:,pos2:,way:false)
      noteitem = if way.is_a? Fixnum then
                   FlickNote(way,at,pos2,pos1)
                 else
                   TapNote(at,pos2,pos1)
                 end
      @notes.store(id,noteitem)
    end
    
    def define_hold(note1, note2)
      HoldNote(note1,note2)
    end
    
    def define_pair(note1, note2)
      PairNotes(note1,note2)
    end
    
    def define_slide(*notes)
      SlideNotes(*notes)
    end
    
    def add_pattern(note)
      fail TypeError, "Expected BaseNote or MixNotes class, given #{note.class}" unless note.is_a? BaseNote || note.is_a? MixNotes
      @pattern << note
    end
    
    # protected methods
    protected
    
    # public methods
    public
    
    # class methods
    class << self
      # private static methods
      private
      alias :_df_new :new
            
      # protected static methods
      protected
      
      # public static methods
      public
      
      # new(klass,*args,&block)
      # klass [Class] - a supplied class for the builder, expected to be inheritance of BasicChart
      def new(klass,*args,&block)
        fail TypeError, "Expected `klass' is class, given #{klass.class}" unless klass.is_a? Class
        fail TypeError, "Expected BasicChart class, given #{klass}" unless klass.ancestors.include? BasicChart
       
        if block.is_a? Proc then
          builder = _df_new(*args)
          yield builder
          klass.new(builder)
        end
      end
    end
  end
  
  class BaseNote
    "Represents a standard definition of a note
    "
    TimingModes = [:exact,:rhythmic].freeze
    
    # constructor
    def initialize(time,pos,source=nil)
      fail TypeError,sprintf("Expecting Time-object or Floats, given %s",
        pos.class) unless [Numeric,Time].any? { |cls| cls === time }
      fail TypeError,sprintf("Expecting Low-ranged Integer (1..5), given %s %s",
        pos,pos.class) unless pos.is_a?(Integer) && pos.between?(1,5)
      
      self.time = time
      self.pos  = pos
      self.cpos = source
    end
    
    # accessors
    public
    def time
      @time
    end
    def pos
      return @pos
    end
    def cpos
      return @cpos.nil? ? @pos : @cpos
    end
    
    def time=(time)
      case @@timing_mode
      when :exact
        @time = Float(time)
      when :rhythmic
        @time = Timing(time)
      end
    end
    def time!
      self.time = @time
    end
    def pos=(pos)
      @pos  = ((pos.to_i() if pos.to_i.between?(1..5)) rescue @pos)
    end
    def cpos=(cpos)
      @cpos = ((cpos.to_i() if cpos.nil? || cpos.to_i.between?(1..5)) rescue @cpos)
    end
    
    # private methods
    private
    
    # protected methods
    protected
    
    # public methods
    public
    
    # class methods
    class << self
      # private static methods
      private
      
      # protected static methods
      protected
      
      # public static methods
      public
      def timing_mode
        TimingModes.include?(@@timing_mode) ? @@timing_mode : TimingModes.first
      end
      
      def timing_mode=(value)
        @@timing_mode = TimingModes.include?(value) ? value : self.timing_mode
        ObjectSpace.each_object(self) { |cls|
          ObjectSpace.each_object(cls,&:time!)
        }
      end
      
      timing_mode = nil
    end
  end
  class TapNote < BaseNote
  end
  class FlickNote < BaseNote
    "Class Description"
    # constructor
    def initialize(face,time,position,source=nil)
      fail TypeError,sprintf("Expecting Integer, given %s for Note Facing",
        face.class) unless [Fixnum].any? { |cls| cls === time }
      self.dir = face
    end
    
    # accessors
    public
    def dir
      @dir
    end
    
    def dir=(facing)
      return dir unless facing.is_a? Fixnum
      @dir = facing
    end
    
    # private methods
    private
    
    # protected methods
    protected
    
    # public methods
    public
    
    # class methods
    class << self
      # private static methods
      private
      
      # protected static methods
      protected
      
      # public static methods
      public
      
    end
  end
  
  class MixNotes
    "Represents a combination of notes.
    
    It's start time and end time determined by notes that
    composes this class itself.
    "
    
    # constructor
    def initialize(initData=[],baseClass=[],direClass=[],indexLock=false,strict=false,limit=2)
      # Direct Array Checker
      [
        ["initializing",initData,BasicObject],
        ["sub-class",baseClass,Class],
        ["direct-class",direClass,Class]
      ].each { |item|
        fail TypeError, "Expecting #{item[0]} array but given #{item[1].class}" unless item[1].instance_of?(Array)
        item[1].each_with_index { |itemData,itemId|
          fail TypeError, "Expecting #{item[0]} items of #{item[2]} but given #{itemData.class} on index #{itemId.class}" unless itemData.is_a?(item[2])
        }
      }
      
      fail ArgumentError, "Cannot specify total-immutable of MixNotes" if [baseClass,direClass].all? { |ary| ary.empty? }
      
      @arraySCls  = baseClass.dup.freeze
      @arrayDCls  = direClass.dup.freeze
      @setOfItem = initData.dup.freeze
      @indexLock  = !!indexLock
      @arrayLimit = 0..Float::INFINITY
      
      self[].each { |item,idx| type_checker item,idx }
      @array_limit = limit if [Integer,Array,Range].any? { |cls| cls === limit }
      @strict = !!strict
      
      limit_checker(@setOfItem.size)
    end
    
    # accessors
    public
    def [](*keys)
      case keys.length
      when 0
        @setOfItem.each_with_index
      else
        @setOfItem.values_at(*keys)
      end
    end
    def []=(key,value)
      fail TypeError, sprintf("Expected Integer key given %s",
        key.class) unless key.is_a?(Integer)
      
      allowedRange = Range.new(*([@setOfItem.size,~@setOfItem.size].sort));
      fail RangeError, sprintf("Index given out of bound, given %d expected %s",
        key,allowedRange) if allowedRange.include?(key)
      typeChecker(value,key)
      @setOfItem[key]=value
    end
    def start
      @setOfNote.first
    end
    def end
      @setOfNote.last
    end
    
    # private methods
    private
    def type_checker(item,idx)
      if @indexLock then
        # Perform looping index-based type checker
        baseClass = @arraySCls[idx % @arraySCls.size] rescue nil;
        direClass = @arrayDCls[idx % @arrayDCls.size] rescue nil;
        unless (item.is_a?(baseClass) rescue false) ||
          (item.instance_of?(direClass) rescue false) then
          
          fail TypeError, sprintf("Expected %s, but given %s instead",[
            baseClass.nil? ? '' :
              sprintf("%s and it's descendant",baseClass),
            direClass.nil? ? '' :
              sprintf("%s itself",direClass),
          ].select{|str| !str.empty? }.join(' or '),item.class)
        end
      else
        # Perform non-index class based type-checker
        unless @arraySCls.any? { |cls| item.is_a?(cls) } ||
          @arrayDCls.any? { |cls| item.instance_of?(cls) } then
          
          fail TypeError, sprintf("Expected %s, but given %s instead",[
            @arraySCls.empty? ? '' :
              sprintf("any class based off %s",@arraySCls.join(',')),
            @arrayDCls.empty? ? '' :
              sprintf("direct-class of %s",@arrayDCls.join(','))
          ].select{|str| !str.empty? }.join(' or '), item.class)
        end
      end
    end
    def limit_checker(newVal)
      min,max = 0,0
      case @arrayLimit
      when Range
        min,max = @arrayLimit.begin,@arrayLimit.end
      when Numeric
        min,max = [@arrayLimit.floor()] * 2
      when Array
        min,max = @arrayLimit.min(),@arrayLimit.max()
      end
      
      ret = newVal.between?(min,max)
      fail RangeError, sprintf("Composition change failed, strict mode is set for %d of %.0f..%.0f",
        newVal,min,max) if @strict && !ret
      ret
    end
    def master_array_insert(meth,items,typeCheck=false,retCount=true)
      succ = 0
      elmt = []
      
      items.each { |item|
        next unless limit_checker(@setOfItem.length+1)
        type_checker(item,@setOfItem.length+1) if typeCheck
        
        @setOfItem.method(meth).call(item)
        elmt.push(item)
        succ += 1
      }
      @setOfNote.sort!
      
      retCount ? succ : elmt
    end
    def master_array_remove(meth,count)
      elmt = []
      empty = @setOfItem.empty?
      count.times {
        next unless limit_checker(@setOfItem.length-1)
        elmt.push(@setOfItem.method(meth).call())
      }
      @setOfNote.sort!
      
      empty ? nil : (elmt.length > 1 ? elmt : elmt.pop())
    end
    
    # protected methods
    protected
    
    # public methods
    public
    def push(*items);master_array_insert(__method__,items,true,true);end
    def unshift(*items);master_array_insert(__method__,items,true,true);end
    def pop(count=1);master_array_remove(__method__,count);end
    def shift(count=1);master_array_remove(__method__,count);end
    
    # class methods
    class << self
      # private static methods
      private
      
      # protected static methods
      protected
      
      # public static methods
      public
      
    end
  end
  class PairNotes < MixNotes
    "Representing a pair of notes
    
    Ensures given pair of notes are requires
    interaction at the same time.
    "
    
    # constructor
    def initialize(sideLft,sideRgt)
      super([sideLft,sideRgt],[BaseNote],[],false,true,2)
    end
  end
  class HoldNote < MixNotes
    "Representing a pair of notes
    
    Ensures given pair of notes is only interactable
    by sequence from first one to second one.
    "
    
    # constructor
    def initialize(sideHed,sideTel)
      super([sideHed,sideTel],[TapNote,BaseNote],[],true,true,2)
    end
  end
  class SlidePath < MixNotes
    "Representing a chain of flick notes
    
    Constructs a path along given set of flicks,
    to make a chain of sliding notes.
    " 
    
    # constructor
    def initialize(*slideChain)
      super(slideChain,[],[FlickNote],true,true,2..Float::INFINITY)
    end
  end
  GlobalConstDeclare(self)
end

# INCLUSION LINE ENDS HERE

if __FILE__ == $0 then
  puts("Loaded main module.")
else
  puts("Included #{__FILE__} module")
end
