#!/usr/bin/env ruby

require_relative 'batch_parser'

module ChartAnalyzer;class AutoBPM
  include FinalClass
  
  CALIBRATOR_LIMIT = {upper: Rational(60,80), lower: Rational(28.5,99)}
  MAX_RANGE = 0..Float::INFINITY
  CALIBRATION_STEP = Rational(1,2)
  
  attr_reader :setup, :timing_set, :mapped_time
  
  def initialize(song_id:)
    @song_id     = [[(Integer(String(song_id),10) rescue 0),1].max,999].min
    @parser      = BatchParser.new(song_id: song_id)
    @charts      = @parser.parse
    
    @fixed_conf  = {}
    @setup       = {}
    @timing_set  = {}
    @mapped_time = Hash.new
    
    @local = Hash.new do |h,k,*args|
      k = k.to_s.to_sym
      fail "Clashing local variable name" if methods.include? k
      
      self.singleton_class.instance_exec(@local) do |loc|
        define_method k do loc[k] end
        private k
      end
      
      nil
    end
  end
  
  private
  def calibrate(time)
    return time if time <= 0.0
    if !time.between?(CALIBRATOR_LIMIT[:lower],CALIBRATOR_LIMIT[:upper])
      time *= 0.5 while time > CALIBRATOR_LIMIT[:upper]
      time *= 2.0 while time < CALIBRATOR_LIMIT[:lower]
    end
    time
  end
  
  def bpm_invert(time)
    Rational(60,time)
  end
  
  def load_fixed_timing
    return unless Dir.exists?('chart.timing')
    setup_file = ->(fn) {
      next unless File.exists?(fn)
      
      JSON.load(File.read(fn)).tap do |json|
        if json.key?(:config) then
          @fixed_conf[:setup] = json.delete(:config).map{ |k,v| [k.to_sym,v] }.to_h
        end
        
        if json.key?(:timing) then
          @fixed_conf[:timing_set] = json.delete(:timing).map{ |k,v| [Rational(k),Rational(*v).rationalize(1e-3)] }.to_h
        end
        
        if json.key?(:mapped) then
          @fixed_conf[:mapped_time] = json.delete(:mapped).map{ |k,v| [Float(String(k)),Rational(*v)] }.to_h
        end
      end
      
      @fixed_conf.each do |key, data|
        instance_variable_get("@#{key}").replace(data)
      end
    }
    
    fn = File.join('chart.timing',"%03d.revised.json" % @song_id)
    if File.exists?(fn) then
      setup_file.call(fn)
    end
    
    fn = File.join('chart.timing',"%03d.json" % @song_id)
    if @fixed_conf.empty? && File.exists?(fn) && Time.now <= File.mtime(fn) + 3 * 86400 then
      setup_file.call(fn)
    end
    
    !@fixed_conf.empty?
  end
  
  def get_first_timing
    titr  = 0
    notes_time = cary.map(&:first)
    actual_time = nary.map(&:first)
    tdiv  = [1] * notes_time.size
    tpass = false
    tback = true
    begin
      begin
        unless tpass
          tnotes = notes_time.each_with_index.map{|x,i|Rational(x,tdiv[i]).round(7)}
          # p tnotes.map(&:to_f)
          tlow  = tnotes.min
          thigh = tnotes.max
          tbpm  = bpm_invert(calibrate(tlow)).round(2)
          # puts "stop? @#{titr} #{tnotes.map(&:to_f)} #{tbpm.to_f}" if tnotes.all? {|tnow| (tnow - tlow).abs < 5e-6 }
          break if tnotes.all? { |tnow| (tnow - tlow).abs < 5e-6 } if tbpm.denominator <= 1
        end
        
        break if titr >= 100000
        size.times do |cptr|
          tnow = tnotes[cptr]
          tdiv[cptr] += CALIBRATION_STEP if tnow == thigh
        end
      ensure
        titr += 1
        tpass = false
      end until titr >= 100000
      tpass = true
      tbpm = bpm_invert(calibrate(calibrate(tlow) * CALIBRATION_STEP)).round(2)
      time_shift = 0
      
      begin
        time_shift += 4
      end while actual_time.min < (time_offset = actual_time.max - time_shift * bpm_invert(tbpm))
      time_offset = time_offset.round(7)
      # puts "#{"%03d" % @song_id} BPM: #{"%7.3f" % tbpm} @#{"%.3f" % time_offset}s (#{titr.pred})"
      
      # Check first N time sets
      # Get the shifted and mapped time at once
      # If fails, redone the whole thing.
      -> {
        xary = cary.flatten
        xary.uniq!
        xary.sort!
        xary.map! { |time| time - time_offset }
        xary.map! { |time| [time.round(7), Rational(time,bpm_invert(tbpm)).rationalize(1e-4)] }
        
        tback &= xary.first(5).any?{ |(time,tmap)|
          false ? (![1,2,3].include?(tmap.denominator)) : ( !/^11?0*$/.match(tmap.denominator.to_s(2)) )
        }
      }.call
    end while tback && titr < 100000
    
    @setup.store :start_time, time_offset
    @timing_set.clear
    @timing_set.store Rational(0), tbpm
  end
  
  def detect_timing
    csiz  = 1
    sary  = nary                   # please refer nary and cary, sary is common pointer on this function
    tlist = sary.flatten.uniq.sort # Maximum time
    tptr  = [0]                    # sary pointer, current mark
    sptr  = [0]                    # sary pointer, success mark
    cnum  = (true ? 1 : sary.size).times
    
    toff  = @setup[:start_time]    # Seconds offset
    tadd  = Rational 0             # Measure offset
    tchg  = false                  # Repeat flag
    
    slen  = Rational 1,1       # Lookahead distance
    trat  = Rational 1,2       # Multiplication of lhit
    lhit  = [-1]               # Movement steps
    tline = [nil]              # Base line
    mlim  = 6
    dtol  = 5e-6
    tlen  = Rational 7,4
    tlenp = Rational 0
    
    tmat  = []
    tbpm  = 120
    
    tlook = []
    
    # Mapped time
    gtime = ->(len){[(toff + bpm_invert(tbpm) * Rational(trat * len)).to_f, tadd + Rational(trat * len)]}
    # TIME TO MEASURE: Measure offset + (Given time - Set offset)/(Current BPM)
    stime = ->(time){tadd + Rational(time - toff,bpm_invert(tbpm)).rationalize(1e-3)}
    # MEASURE TO TIME: (Given measure - Measure offset) * (Current BPM) + Set offset
    ntime = ->(time){((time - tadd) * bpm_invert(tbpm) + toff).round(7)}
    # CURRENT POINTER: (Current pointer + Current Delta * Movement Size)
    ztime = ->(){tline[0] + lhit[0] * trat}
    # LAZY SNAP MARK:
    smark = ->(cms){!cms.numerator.zero? && [1,2].include?(cms.denominator)}
    # QUICK SNAP TIME:
    qsnap = ->(cftime){ ->(cctime){ Rational(cctime - cftime,bpm_invert(tbpm)).rationalize(5e-4) } }
    begin
      tbpm = @timing_set[tadd]
      # tline.concat MAX_RANGE.lazy.map { |n| [(toff + bpmize.call(tbpm) * Rational(trat * n)).to_f,tadd + Rational(trat * n)] }.take_while { |(ntime,time)| ntime <= tmax[-1] + 1e-5 }.to_a
      if tline.all?(&:nil?) then
        # Empty time mapping, fill with all data
        tline.replace tlist.slice(0,1).map(&stime).map(&:floor).map(&Kernel.method(:Rational))
        tchg = true
      else
        # Available time mapping
        tchg = false
        # puts "%03d %+8.3f(%+4d/%d) %6.2fbpm" % [@song_id, toff,tadd.numerator,tadd.denominator,tbpm]
        
        # Detect BPM
        cptr = 0
        begin
          break if tlist[tptr.first].nil?
          lhit[0] += 1
          ctime    = ztime.call
          xtime    = stime.call tlist[tptr.first]
          # p [tline[0],lhit[0],ntime.call(ctime),ctime] if ctime
          if (ctime - xtime).abs > dtol && ctime > xtime then
            # miss
            lhit[cptr] -= 1
            tptr[cptr] += 1
          else
            # iterating closer
            tnext = Rational(xtime - ctime,bpm_invert(tbpm))
            # p [ntime.call(ctime),tlist[tptr.first],(xtime - ctime).rationalize(5e-3),tlen+tlenp]
            if tnext < tlen+tlenp then
              # within threshold
              -> {
                cftime = ntime.call(ctime)
                tlook.push(*tlist.slice(tptr.first, mlim.succ))
                this_lookup = tlook.dup
                tlook.map!(&qsnap.call(cftime))
                tlook.reject!(&:zero?)
                
                # Cancel if 1/2, 1/3, or N/1 detected
                # p tlook
                if tlook.empty?
                  tchg |= true
                  break
                elsif !tlook.any?(&smark)
                  next_lookup    = tlist.slice(tptr.first,mlim * 2)
                  new_delta_time = nil
                  this_lookup.map { |tpbpm|
                    if (tpbpm - cftime).abs <= dtol then
                      [tpbpm,Rational(0),0]
                    else
                      plus_lookup = next_lookup.map{|cctime|Rational(cctime-cftime,tpbpm-cftime).rationalize(5e-4)}
                      valid = plus_lookup.count(&smark)
                      plus_lookup.clear
                      [tpbpm,(Rational(tpbpm - cftime,60/tbpm) - 1).rationalize(1e-4).abs, valid]
                    end
                  }.tap { |mapped_time|
                    if true
                      best_value = mapped_time.max{ |(tpbpm1,ratio1,match1),(tpbpm2,ratio2,match2)|
                        (match1 <=> match2).nonzero? ||
                        (ratio2 <=> ratio1).nonzero? ||
                        (calibrate(tpbpm2 - cftime).denominator <=> calibrate(tpbpm1-cftime).denominator).nonzero? ||
                        tpbpm2  <=> tpbpm1
                      }.first - cftime
                      new_delta_time = calibrate(best_value).round(6)
                    end
                    mapped_time.clear
                  }
                  next_lookup.clear
                  #bpm_invert(new_delta_time).rationalize(5e-3).tap { |ndt|
                  #  p [ctime,ndt,ndt.to_f]
                  #}
                  case bpm_invert(new_delta_time).rationalize(5e-3).denominator
                  when 1
                  when 2
                    new_delta_time = [
                      [3,2],[2,3]
                    ].map { |(rn,rd)| calibrate(new_delta_time * rn / rd) }
                      .min{ |time|
                        bpm_invert(time).rationalize(5e-3).denominator
                      }
                  when 3
                    new_delta_time = calibrate(new_delta_time / 3)
                  else
                    # p [ctime,ctime.round(3).to_f,bpm_invert(new_delta_time).rationalize(5e-3).to_f,new_delta_time]
                    new_delta_time = nil
                  end
                  
                  interrupt_flag  = new_delta_time.nil?
                  unless interrupt_flag
                    # interrupt_flag |= new_delta_time > 1
                    -> {
                      current_bpm = @timing_set.values.last
                      propose_bpm = bpm_invert(new_delta_time).rationalize(5e-3)
                      interrupt_flag |= (current_bpm - propose_bpm).abs <= 1e-5
                      interrupt_flag |= Rational(propose_bpm,current_bpm).denominator == 1
                      interrupt_flag |= Rational(current_bpm,propose_bpm).denominator == 1
                    }.call
                  end
                  interrupt_flag |= @timing_set.key? ctime
                  interrupt_flag |= !/^10*/.match(ctime.denominator.to_s)
                  # p [ctime.denominator,new_delta_time]
                  unless interrupt_flag
                    tchg |= true
                  
                    tadd       += ctime  - tadd
                    toff       += cftime - toff
                    lhit[cptr]  = -1
                    tline[0]    = tadd
                    tlenp      += 8 - tlenp
                    
                    @timing_set.store ctime, bpm_invert(new_delta_time).rationalize(5e-3)
                  end
                else
                end
                this_lookup.clear
              }.call
            else
              # Far enough within threshold
            end
          end
          tlook.clear
          tlenp -= 1 if tlenp > 0
        end while !tchg
        
        # Post-BPM Detection
        tchg &= !tlist[tptr.first.succ].nil?
      end
    end while tchg
    # p tline
    #p tmat.size
    tline.clear
    tmat.clear
    #puts "#{song_id}: #{tset}"
  end
  
  def snap_timing
    # Initialize variables
    sary  = nbry
    tlist = sary.flatten.uniq.sort
    
    tbpm  = Rational 120
    tadd,toff = Rational(0), @setup[:start_time]
    
    # TIME TO MEASURE: Measure offset + (Given time - Set offset)/(Current BPM)
    stime = ->(time){tadd + Rational(time - toff,bpm_invert(tbpm)).rationalize(5e-3)}
    # MEASURE TO TIME: (Given measure - Measure offset) * (Current BPM) + Set offset
    ntime = ->(time){((time - tadd) * bpm_invert(tbpm) + toff).round(7)}
    
    (@timing_set.to_a + [[Float::INFINITY,Rational(120)]]).each_cons(2) do |((cms,cbpm),(nms,nbpm))|
      tbpm  = cbpm
      noff  = ((nms - cms)*bpm_invert(cbpm) + toff).round(7)
      tlist.select { |ctime| ctime >= toff && ctime < noff }.each do |ctime|
        # p [cbpm,ctime,stime.call(ctime),toff,noff]
        @mapped_time.store(ctime,stime.call(ctime))
      end
      
      toff = noff
      tadd = nms.to_r rescue nms
    end
  end
  
  def store_timing
    @setup[:start_time] = [@setup[:start_time].round(6),0.0].max
    Dir.mkdir('chart.timing') if !Dir.exists?('chart.timing')
    Dir.chdir('chart.timing') do
      File.write(
        "%03d.json" % @song_id,
        JSON.neat_generate(
          {
            config: @setup,
            timing: @timing_set.map{|toff,bpm| [toff.to_f,bpm.to_f]},
            mapped: @mapped_time.map{|time,measure| [time,[measure.numerator,measure.denominator]]}.to_h
          }
        )
      )
    end
  end
  
  public
  def size
    @charts.size
  end
  def charts
    @charts
  end
  
  def get_bpm
    # Get only Tap Note that have unique time.
    @local[:zary] ||= charts.map(&:notes).map(&:values)
    @local[:cary] ||= @local[:zary].map{ |chart_notes| chart_notes.select{|x| TapNote === x || SlideNote === x }.uniq(&:time).map(&:time) }
    @local[:nary] ||= @local[:zary].map{ |chart_notes| chart_notes.uniq(&:time).map(&:time) }
    @local[:nbry] ||= @local[:nary] | charts.map(&:raws).compact.map(&:values).map{|rawc|rawc.uniq{|t|t[:at]}.map{|t|t[:at]}.compact}
    
    load_fixed_timing
    
    if @fixed_conf.empty? then
      get_first_timing
      
      detect_timing
    end
    
    if !@fixed_conf.key?(:mapped_time) then
      snap_timing
      store_timing
    end
  end
  
  alias :inspect :to_s
  
  class << self
    def main(*argv)
      new(song_id: argv.shift).instance_exec { get_bpm }
    end if is_main_file
    
    -> {
      old_new = instance_method(:new)
      cache = {}
      define_method :new do |*argv|
        sid = String(argv.first[:song_id])[0,3].rjust(3,'0')
        if cache.key?(sid) then
          cache.fetch(sid)
        else
          data = old_new.bind(self).call(*argv)
          cache.store(sid,data)
          data
        end
      end
    }.call
  end
end;end

def main(*argv); ChartAnalyzer::AutoBPM.main(*argv); end if is_main_file
