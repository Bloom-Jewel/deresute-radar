#!/usr/bin/env ruby

require 'fiber'
require 'continuation'

require_relative 'batch_parser'

module ChartAnalyzer;class AutoBPM
  include FinalClass
  
  CALIBRATOR_LIMIT = {upper: Rational(30,20), lower: Rational(28.5,99)}
  MAX_RANGE = 0..Float::INFINITY
  CALIBRATION_STEP = Rational(1,2)
  
  
  def initialize(song_id:)
    @song_id     = [[(Integer(song_id,10) rescue 0),1].max,999].min
    @parser      = BatchParser.new(song_id: song_id)
    @charts      = @parser.parse
    
    @setup       = {}
    @timing_set  = {}
    @mapped_time = Array.new(size) { Hash.new }
    
    @local = Hash.new do |h,k|
      k = k.to_s.to_sym
      fail "Clashing local variable name" if methods.include? k
      
      self.singleton_class.instance_exec(@local) do |loc|
        define_method k do loc[k] end
        private k
      end
      
      nil
    end
    
    @backtrack   = nil
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
  
  def get_first_timing
    titr = 0
    notes_time = cary.map(&:first)
    actual_time = nary.map(&:first)
    tdiv = [1] * notes_time.size
    tpass = false
    callcc do |cc| @backtrack = cc end

    begin
      unless tpass
        tnotes = notes_time.each_with_index.map{|x,i|Rational(x,tdiv[i]).round(6)}
        # p tnotes.map(&:to_f)
        tlow  = tnotes.min
        thigh = tnotes.max
        tbpm  = bpm_invert(calibrate(tlow)).round(2)
        # puts "stop? @#{titr} #{tnotes.map(&:to_f)} #{tbpm.to_f}" if tnotes.all? {|tnow| (tnow - tlow).abs < 5e-6 }
        break if tnotes.all? { |tnow| (tnow - tlow).abs < 5e-6 } if tbpm.denominator <= 1
      end
      
      break (@backtrack = nil) if titr >= 100000
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
    time_offset = time_offset.round(6)
    puts "#{"%03d" % @song_id} BPM: #{"%7.3f" % tbpm} @#{"%.3f" % time_offset}s (#{titr.pred})"
    
    @setup.store :start_time, time_offset
    @timing_set.clear
    @timing_set.store Rational(0), tbpm
    
  end
  
  def snap_timing
    csiz  = 1
    sary  = nary # please refer nary and cary, sary is common pointer on this function
    tptr  = [0] * sary.size    # sary pointer
    sptr  = [0] * sary.size    # sary pointer
    cnum  = sary.size.times
    
    toff  = @setup[:start_time] # Seconds offset
    tadd  = Rational 0         # Measure offset
    tchg  = false              # Repeat flag
    tmax  = sary.flatten.uniq.sort # Maximum time
    
    trat  = Rational 1,2       # Multiplication of lhit
    lhit  = [0] * sary.size    # Movement steps
    tline = [nil] * sary.size  # Base line
    mlim  = 8
    dtol  = 5e-6
    
    tmat  = []
    tbpm  = 120
    
    gtime = ->(len){[(toff + bpm_invert(tbpm) * Rational(trat * len)).to_f, tadd + Rational(trat * len)]}
    # Measure offset + (Given time - Set offset)/(Current BPM)
    stime = ->(time){tadd + Rational(time - toff,bpm_invert(tbpm)).rationalize(0.005)}
    # (Given measure - Measure offset) * (Current BPM) + Set offset
    ntime = ->(time){((time - tadd) * bpm_invert(tbpm) + toff).round(6)}
    # (Current pointer + Current Delta * Movement Size)
    ztime = ->(iptr){tline[iptr] + lhit[iptr] * trat}
    begin
      tbpm = @timing_set[tadd]
      # tline.concat MAX_RANGE.lazy.map { |n| [(toff + bpmize.call(tbpm) * Rational(trat * n)).to_f,tadd + Rational(trat * n)] }.take_while { |(ntime,time)| ntime <= tmax[-1] + 1e-5 }.to_a
      if tline.all?(&:nil?) then
        tline.replace sary.map(&:first).map(&stime).map(&:floor).map(&Kernel.method(:Rational))
        tchg = true
        next
      end
      
      tchg = false
      puts "%03d %+6.3f(+%s) %6.2fbpm" % [@song_id, toff,tadd,tbpm]
      
      # Detect BPM
      cjmp = nil
      begin
        callcc do |cc| cjmp = cc end
        cptr = 0
        begin
          lpass = false
          if lhit[cptr] > mlim
            lpass |= stime.call(sary[cptr][tptr[cptr]]).denominator.to_s(2) =~ /^1[10]?0*$/
            next unless lpass
          else
            next if tptr[cptr] >= sary[cptr].size
            lhit[cptr] += 1
           
            ltime = ztime.call cptr
            lpos  = ntime.call ltime
            linv  = 0
            cinv  = ->{linv *= 0.0; linv += (sary[cptr][tptr[cptr]] - lpos).round(6)}
          end
          next if lpos > tmax[-1]
          tptr[cptr] += 1 while tptr[cptr] < sary[cptr].size and (cinv.call <= -dtol)
          next if tptr[cptr] >= sary[cptr].size
          
          if lpass || (cinv.call <= dtol) then
            tline[cptr] = ltime
            lhit[cptr] = 0
            sptr[cptr],tptr[cptr] = tptr[cptr],tptr[cptr].succ
          else
            puts "%s:%d %3d:%3d %10s %10s" % [
              @song_id,cptr,
              sptr[cptr],tptr[cptr],
              stime.call(sary[cptr][sptr[cptr]]),
              stime.call(sary[cptr][tptr[cptr]])
            ] if false
          end
        ensure
          cptr += 1
        end while cptr < sary.size
        # puts "#{song_id} #{lhit} #{tptr} #{sary.map(&:size)}"
        break if cnum.all?{|cptr|a,b,c,d = tptr[cptr].succ,sary[cptr].size,ntime.call(ztime.call(cptr)),sary[cptr][-1];a >= b || c >= d}
        tchg = cnum.all?{|cptr|tptr[cptr].succ >= sary[cptr].size || lhit[cptr] > mlim}
      end while !tchg
      
      # Post-BPM Detection
      if lhit.all?{|lnum|lnum>mlim}
        # Redone if next denominator is valid
        cjmp.call if cjmp && cnum.any?{|cptr|(tadd + Rational( sary[cptr][tptr[cptr]] - toff,bpm_invert(tbpm) ).rationalize(0.03) ).denominator.to_s(2) =~ /^1[10]?0*$/}
        
        # Reset if previous pointer all zero
        if sptr.all?(&:zero?) then
          @backtrack.call if @backtrack
          fail "badly setup timing"
        end
        
        # Reset step
        lhit.fill(Rational(0))
        puts "diff  %s" % [cnum.map{|x|Rational(sary[x][tptr[x]] - ntime.call(ztime.call(x)),bpm_invert(tbpm)).rationalize(0.03)}]
        puts "smea  %s" % [cnum.map{|x|ztime.call(x)}]
        puts "vtime %s" % [cnum.map{|x|ntime.call(ztime.call(x))}]
        puts "ptime %s" % [cnum.map{|x|sary[x][sptr[x]]}]
        puts "ctime %s" % [cnum.map{|x|sary[x][tptr[x]]}]
        puts '-' * 20
        
        # Reset pointer
        tptr.fill{|i|sptr[i]}
        
        # TODO: guess from 4 ticks away from this
        -> {
          
        }.call
        break
      else
        # Success full break
        break
      end
    end while tchg
    # p tline
    #p tmat.size
    tline.clear
    tmat.clear
    #puts "#{song_id}: #{tset}"
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
    @local[:cary] ||= @local[:zary].map{ |chart_notes| chart_notes.select{|x| TapNote === x || SuperNote === x }.uniq(&:time).map(&:time) }
    @local[:nary] ||= @local[:zary].map{ |chart_notes| chart_notes.uniq(&:time).map(&:time) }
    
    get_first_timing
    
    snap_timing
  end
  
  alias :inspect :to_s
    
  def self.main(*argv)
    new(song_id: argv.shift).instance_exec { get_bpm }
  end if is_main_file
end;end

def main(*argv); ChartAnalyzer::AutoBPM.main(*argv); end if is_main_file
