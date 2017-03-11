#!/usr/bin/env ruby

require 'json'
require 'neatjson'
require 'find'
require 'uri'

require_relative '../lib/final_class'
require_relative '../lib/deremod'
require_relative '../lib/framework'

require_relative 'chart_parser'

class ChartTimeChecker
  include FinalClass
  CALIBRATOR_LIMIT = {upper: Rational(30,40), lower: Rational(24,99)}
  def initialize(*argv)
    @parser = ChartParser.new(*argv)
    @chart_group = @parser.parse_charts
    get_intervals
  end
  def get_intervals
    balance   = ->(time,mult,desired){
      [((time * mult) - desired).abs,((time / mult) - desired).abs].min <= 1e-5
    }
    calibrate = ->(time){
      return time if time <= 0.0
      if !time.between?(CALIBRATOR_LIMIT[:lower],CALIBRATOR_LIMIT[:upper])
        time *= 0.5 while time > CALIBRATOR_LIMIT[:upper]
        time *= 2.0 while time < CALIBRATOR_LIMIT[:lower]
      end
      time
    }
    bpmize    = ->(time){ Rational(60,time) }
    dcheck    = 10
    
    @chart_group.each do |song_id, charts|
      setup = {}
      # Get only Tap Note that have unique time.
      cary = charts.map(&:notes).map(&:values).map{ |chart_notes| chart_notes.select { |note| note.is_a? TapNote }.uniq { |note| note.time } }
      # Index Pointer
      iptr = [0] * cary.size
      # Chart Finish Flag
      cfin = [false] * cary.size
      # Old Pointer
      optr = [0.0] * cary.size
      # Time Pointer
      tptr = [0.0] * cary.size
      # Time Interval
      tinv = [0.0] * cary.size
      iaru = {}
      tset = {}
      
      # Gather Timing Differences
      cary[0].size.times do |cue|
        next if iptr[0] > cue
        if cue == 0 then
          notes_time = cary.map(&:first).map(&:time)
          setup.store :start_time,notes_time.max
          tptr.fill { |cptr| notes_time[cptr] }
        end
        
        ifoc = Array.new(cary.size) { [] }
        tcue = tptr.max
        
        begin
          cptr = 0
          tmax = tptr.max
          cfin.fill { |i| iptr[i].succ >= cary[i].size }
          begin
            begin
              optr[cptr], tptr[cptr] = tptr[cptr], cary[cptr][iptr[cptr]].time
              if calibrate.call(tptr[cptr] - optr[cptr]).abs > 1e-6 then
                tinv[cptr] = (calibrate.call(tptr[cptr] - optr[cptr])).round(6)
                ifoc[cptr] << tinv[cptr]
              end
              puts [
                     "[#{(0...cary.size).map { |x| (cptr == x) ? ("\x1b[31;1m%s\x1b[m" % iptr[x]) : iptr[x] } * ', '}]",
                     "[#{(0...cary.size).map { |x| (cptr == x) ? ("\x1b[33;1m%s\x1b[m" % optr[x]) : optr[x] } * ', '}]",
                     "[#{(0...cary.size).map { |x| (cptr == x) ? ("\x1b[32;1m%s\x1b[m" % tinv[x]) : tinv[x] } * ', '}]",
                   ] * ' ' if true
            end unless cfin[cptr]
          ensure
            cfin[cptr] = (tptr[cptr] >= tmax) || (iptr[cptr].succ >= cary[cptr].size)
            unless cfin[cptr] then
              iptr[cptr] += 1
            end
            cptr = (cptr + 1) % charts.size
          end until cfin.all? { |finish| finish }
        end while (0...cary.size).to_a
          .select { |cptr| iptr[cptr].succ < cary[cptr].size }
          .map { |cptr| tptr[cptr] }
          .uniq.size > 1
        
        iaru.store tcue,ifoc
        (0...(charts.size)).each do |cptr|
          iptr[cptr] = [iptr[cptr].succ, cary[cptr].size].min
        end
      end
      p iaru
      
      iaru.each do |note_time, interval_sets|
        index_power = [85,100,110,105,95]
        interval_sets.each_with_index.map { |interval_set,interval_index|
          interval_set.group_by { |x| x.round(5) }
            .map { |k,v| [v.inject(:+).fdiv(v.size).round(6),v.size * index_power[interval_index] / 100] }.to_h
        }.inject { |ch,nh|
          nh.keys.each do |nk|
            ch[nk] ||= 0
            ch[nk]  += 1
          end
          ch
        }.group_by { |k,v| "%.4f" % k }
         .map { |_,d| d=d.to_h; [d.keys.inject(:+).fdiv(d.keys.size).round(6),d.values.inject(:+)] }.to_h
         .tap { |interval_group|
           ik = interval_group.keys
           tt = (Rational(60,ik.map { |ck|
             [
               ck,
               (ik - [ck]).map { |nk| Rational(ck,nk).rationalize(Rational(1,100000)) }
                 .select { |int| /^1{1,2}0*$/.match(int.denominator.to_s(2)) }
             ]
           }.select { |(ck,ib)|
             ib.all? { |x| x <= 1 }
           }.first.first).rationalize(1e-1)) rescue nil
           
           if !tt.nil? && (tset.size.zero? || (tset.values.last - tt).abs > 1e-6) then
             if tset.size.nonzero? then
               rt = Rational(tset.values.last,tt)
               rt = Rational(1,rt) if rt < 1
               rt = rt.rationalize(1e-6)
               
               next if rt.denominator <= dcheck
               p [tset.values.last,tt,rt,rt.denominator,tt.denominator]
             end
             if tt.denominator.between?(2,dcheck) then
               [
                 tt,
                 Rational(tt * tt.denominator,tt.denominator + 1),
                 Rational(tt * (tt.denominator + 1),tt.denominator)
               ].min { |xt| xt.denominator }.tap { |xt|
                 zt = xt
                 begin
                   Rational(zt * (zt.denominator),zt.denominator.pred).tap do |ct|
                     p [zt,ct,zt.to_f,ct.to_f]
                     zt = ct
                   end
                 end
                 if zt >= 150 then
                   zt /= 2 while Rational(60,zt) < CALIBRATOR_LIMIT[:lower]
                 else
                   zt *= 2 while Rational(60,zt) > CALIBRATOR_LIMIT[:upper]
                 end
                 tt = zt
               }
             end
             
             tset.store note_time, tt
           end
         }
      end
      puts "#{song_id} #{tset.map{|k,v|[k,v.to_f]}.to_h}"
    end
  end
  def self.main(*argv)
    new(*argv)
  end if is_main_file
end

def main(*argv); ChartTimeChecker.main(*argv); end if is_main_file
