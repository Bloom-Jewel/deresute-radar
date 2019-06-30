=begin
  DereMod.rb
  
  Starlight Stage Note Composition Breakdown
=end

require_relative 'raw_json'
require_relative 'rhythm'
require_relative 'kernel_snippet'
require_relative 'typed_array'

# INCLUSION LINE STARTS HERE
module Deresute
  class ImportedSong < RawJSON
  end
  class ImportedChart < RawJSON
    def build(**options)
      ChartBuilder.new(Chart,@raw) do |raw|
        options.each do |key,value|
          set_property key,value
        end
        
        raw[:chartData].tap do |chart_data|
          # First iteration - define notes
          chart_data.each do |note_data|
            kw = { id:note_data[:id], at:note_data[:sec], pos1:note_data[:startPos], pos2:note_data[:finishPos], way:note_data[:status], type: note_data[:type] }
            if [1,2,3].include? note_data[:type] then
              define_note **kw
            else
              define_raw **kw
            end
          end
          
          m = {h:{},s:{},p:[]}
          # Second iteration - define holds
          chart_data.select { |note_data| note_data[:type].between?(1,2) }
            .tap do |hold_list|
              hs = [0,0,0,0,0,0]
              hold_list.each do |hold_data|
                i,j,k = *hold_data.values_at(:id,:type,:finishPos)
                if hs[k].nonzero? then
                  m[:h][ hs[k] ] = define_hold(hs[k],i)
                  hs[k] = 0
                elsif j == 2 then
                  hs[k] = i
                end
                # ::Kernel.p hs if get_property(:difficulty) > 2
              end
              
              if hs.any?(&:nonzero?) then
                ::STDERR.puts "Stalling hold note detected"
              end
            end
          
          # Third iteration - define slides
          chart_data.select { |note_data| note_data[:groupId].nonzero? }
            .group_by { |note_data| note_data[:groupId] }
            .tap { |slide_set| next; ::Kernel.p slide_set.map{|k,v|[k,v.size]} }
            .each do |group_id,note_list|
              begin
                m[:s][group_id] = define_slide(*note_list.map{|note|note[:id]})
              rescue TypeError, RangeError
                ::STDERR.puts "Bad slide chain detected: #{note_list.map(&:inspect) * ', '} (#{$!.class}: #{$!.message})"
              end
            end
          
          # Fourth iteration - define pairs
          chart_data.select { |note_data| note_data[:sync].nonzero? }
            .group_by { |note_data| note_data[:sec] }
            .each do |pair_time,pair_note|
              if pair_note.size != 2 then
                ::STDERR.puts "Bad pair setup detected (#{pair_note.size})"
              else
                m[:p] << define_pair(*pair_note.map{|note|note[:id]})
              end
            end
          
          @holds, @slides, @pairs = m.values_at(:h,:s,:p)
        end
      end
    end
  end
  
  class Song
  end
  class BasicChart
    # constructor
    def initialize(build_data)
      fail TypeError, "Expected builder class!" unless ObjectSpace.each_object(ChartBuilder).to_a.include?(build_data)
      build_data.instance_exec(method(:get),method(:set)) do |get,set|
        set.call :diff    , get_property(:difficulty)
        set.call :checksum, get_property(:hash)
        set.call :notes   , get_notes
        set.call :holds   , get_holds
        set.call :slides  , get_slides
        set.call :pairs   , get_pairs
        set.call :raws    , get_raws
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
    def notes;@notes;end
    def holds;@holds;end
    def slides;@slides;end
    def pairs;@pairs;end
    def raws;@raws;end
    def inspect
      "<%s diff:%d note:%d hold:%d slide:%d pair:%d>" % [
        self.class,
        @diff.to_i,
        @notes.size,
        @holds.size,
        @slides.size,
        @pairs.size,
      ]
    end
    
    def method_missing(m,*a,&b)
      if instance_variable_defined?("@#{m}") then
        self.class.class_exec { define_method("#{m}") { instance_variable_get("@#{m}") } }
        send m
      else
        super(m,*a,&b)
      end
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
  
  class ChartBuilder < ::BasicObject
    'Builder based class are formed through DSL'
    'Structure priority'
    '- Pair'
    '- Hold'
    '- Slide'
    '- Tap'
    # constants
    
    # constructor
    def initialize
      @options = {}
      @notes = {}
      @holds = {}
      @slides = {}
      @pairs = []
      @rawcall = {}
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
    
    def get_holds
      @holds
    end
    
    def get_slides
      @slides
    end
    
    def get_pairs
      @pairs
    end
    
    def get_raws
      @rawcall
    end
    
    def set_property(key,val)
      @options.store(key,val)
    end
    
    def define_note(id:,at:,pos1:,pos2:,type:,way:false)
      noteitem = if way.is_a?(::Integer) && way.nonzero? then
                   case way
                   when 1,2
                     FlickNote.new(way,at,pos2,pos1)
                   when 100,101,102
                     TapColorNote.new(way - 99,at,pos2,pos1)
                   else
                     $stderr.puts "WARNING! Note #{id} have status of #{way}"
                     nil
                   end
                 elsif type == 3
                   SuperNote.new(at,pos2,pos1)
                 else
                   TapNote.new(at,pos2,pos1)
                 end
      return if noteitem.nil?
      @notes.store(id,noteitem)
    end
    
    def define_raw(id:,**opts)
      @rawcall.store(id,opts)
    end
    
    ->(){
      note_checker = ->(ary){
        ary.each_index do |i|
          o = ary[i]
          if @notes.has_key? o then
            ary[i] = @notes[o]
          elsif !(o.is_a?(BaseNote) || o.is_a?(MixNotes)) then
            fail ::TypeError, "Expected BaseNote or MixNotes class, given #{o.class}"
          end
        end
      }
      
      ['Hold','Pair','Slide'].each do |type|
        define_method(:"define_#{type.downcase}") do |*notes|
          self.instance_exec(notes,&note_checker)
          ChartBuilder.const_get(:"#{type}Note").new(*notes)
        end
      end
    }.call
    
    def add_pattern(note)
      fail ::TypeError, "Expected BaseNote or MixNotes class, given #{note.class}" unless note.is_a?(BaseNote) || note.is_a?(MixNotes)
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
          builder = _df_new
          builder.instance_exec(*args,&block)
          klass.new(builder)
        end
      end
    end
  end
  
  class BaseNote
    "Represents a standard definition of a note
    "
    TimingModes = [:exact,:rhythmic].freeze
    
    @@timing_mode = nil
    
    # constructor
    def initialize(time,pos,source=nil)
      fail TypeError,sprintf("Expecting Time-object or Floats, given %s",
        time.class) unless [Numeric,Time].any? { |cls| cls === time }
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
      @pos  = ((pos.to_i if pos.to_i.between?(1,5)) rescue @pos)
    end
    def cpos=(cpos)
      @cpos = ((cpos.to_i() if cpos.nil? || cpos.to_i.between?(1,5)) rescue @cpos)
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
        ObjectSpace.each_object(self,&:time!)
      end
    end
    
    self.timing_mode = nil
  end
  class TapNote < BaseNote
    def color
      4
    end
  end
  class TapColorNote < TapNote
    def initialize(color,time,position,source=nil)
      fail TypeError,sprintf("Expecting Integer, given %s for Note Color",
        color.class) unless [Integer].any? { |cls| cls === color }
      self.color = color
      super(time,position,source)
    end
    
    def color
      @color
    end
    
    def color=(new_color)
      return color unless new_color.is_a? Integer
      @color = new_color
    end
  end
  class SuperNote < BaseNote
  end
  class FlickNote < BaseNote
    "Class Description"
    # constructor
    def initialize(face,time,position,source=nil)
      fail TypeError,sprintf("Expecting Integer, given %s for Note Facing",
        face.class) unless [Integer].any? { |cls| cls === face }
      self.dir = face
      super(time,position,source)
    end
    
    # accessors
    public
    def dir
      @dir
    end
    
    def dir=(facing)
      return dir unless facing.is_a? Integer
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
  
  class MixNotes < TypedArray
  end
  
  class PairNotes < MixNotes
    "Representing a pair of notes
    
    Ensures given pair of notes are requires
    interaction at the same time.
    "
    
    # constructor
    build base_class: [BaseNote], index_strict: true, size: 2
  end
  class HoldNote < MixNotes
    "Representing a pair of notes
    
    Ensures given pair of notes is only interactable
    by sequence from first one to second one.
    "
    
    # constructor
    build base_class: [TapNote, BaseNote], index_strict: true, size: 2
  end
  class SlidePath < MixNotes
    "Representing a chain of flick notes
    
    Constructs a path along given set of flicks,
    to make a chain of sliding notes.
    " 
    
    # constructor
    build base_class: [FlickNote,SuperNote], index_strict: false, size: 2..Float::INFINITY
    
    # removes any trailing flicks unless end of SuperHold chains.
    def have_slide?
      @data.first.is_a? SuperNote
    end
    alias :have_shold? :have_slide?
    
    def truncate
      return nil if !have_slide?
      
      s = self.dup
      s.truncate!
    end
    def truncate!
      return nil if !have_slide?
      slide_set = @data.select { |x| x.is_a? SuperNote }
      end_note  = @data[slide_set.size]
      pop_size  = self.length - (slide_set.size + (end_note.nil? ? 0 : 1))
      self.pop(pop_size) if pop_size > 0
      self
    end
  end
  
  [
    [:BaseNote ,BaseNote],
    [:TapNote  ,TapNote],
    [:FlickNote,FlickNote],
    [:SuperNote,SuperNote],
    
    [:MixNotes ,MixNotes],
    [:PairNote ,PairNotes],
    [:HoldNote ,HoldNote],
    [:SlideNote,SlidePath]
  ].each do |(const_name,const_data)|
    ChartBuilder.const_set const_name, const_data
  end

  GlobalConstDeclare(self)
end

# INCLUSION LINE ENDS HERE

if __FILE__ == $0 then
  puts("Loaded main module.")
else
  #puts("Included #{__FILE__} module")
end
