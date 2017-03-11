=begin
  DereChart.rb
  
  Starlight Stage Note Compilation
=end

require_relative 'rhythm'
require_relative 'deremod'

# INCLUSION LINE STARTS HERE
module Deresute
  module Structured
    BeatSet = Struct.new( :timing, :bpm ) do
      def initialize(*args)
        opts = args.last.is_a?(Hash) ? args.pop : Hash.new
        super *args
        opts.select! { |k| members.include? k }
        opts.each_pair do |k, v|
          send "#{k}=", v
        end
        self.timing = Timing(0)    if timing.nil?
        self.bpm    = BPMData(120) if bpm.nil?
      end
      redefine :timing= do |redef,value|
        case value
        when Timing
          redef.call value
        when Array
          redef.call *value
        when Integer
          redef.call value
        else
          self.timing
        end
      end
      redefine :bpm= do |redef,value|
        return self.bpm if !value.is_a?(BPMData)
        redef.call value
      end
      def to_json
        [timing.to_f,bpm.to_f]
      end
      undef :[]
      undef :[]=
      undef :select
    end
    
    class TimingSet
      def initialize
        @offset  = 0.0
        @beatset = [BeatSet(Timing(0),BPMData(120))]
      end
      def set_first_timing(bpm,offset:nil)
        if !@offset.nil?
          @offset = Float(offset) rescue @offset
        end
        
        @beatset.first.bpm = bpm
        [@offset,@beatset]
      end
      def <<(obj)
        case obj
        when BeatSet
          @beatset << obj
        when Array # (timing,bpm) order
          @beatset << BeatSet(*obj)
        when Hash # timing: bpm:
          @beatset << BeatSet(**obj.map{|k,v|[k.to_s.to_sym,v]}.to_h)
        else
          fail TypeError, "unexpected object, given #{obj.class}"
        end
        self
      end
      def each(&block);@beatset.each(&block);end
      def delete(id);@beatset.delete(id) if (id.is_a?(Integer))&&(id>0);end
      def pop(amount=1);@beatset.pop(amount) if (amount.is_a?(Integer))&&(amount > 0)&&@beatset.size.pred.nonzero?;end
      def push(*items);items.each { |o| self<<o };self;end
      def inspect
        "<TimingSet %#016x %s>" % [
          self.__id__,
          @beatset * ', '
        ]
      end
    end
    class NoteLine < TypedArray; build base_class: [BaseNote,MixNotes], size: 5; end
    class NoteSet < TypedArray; build direct_class: [NoteLine]; end
    class PatternSet < TypedArray; build direct_class: [NoteSet]; end
    class SlideSet < TypedArray; build direct_class: [SlidePath]; end
    class DereChart
      "Chart class with sophiscated structure"
      def initialize
        @timingset = Timingset.new
        @notes     = NoteSet.new
        
      end
    end
  end
  GlobalConstDeclare(self)
end

# INCLUSION LINE ENDS HERE

if __FILE__ == $0 then
  puts("Loaded main module.")
end
