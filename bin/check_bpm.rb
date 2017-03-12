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
  CALIBRATOR_LIMIT = {upper: Rational(30,40), lower: Rational(28.5,99)}
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
      zary = charts.map(&:notes).map(&:values)
      cary = zary.map{ |chart_notes| chart_notes.select{|x| TapNote === x }.uniq(&:time).map(&:time) }
      nary = zary.map{ |chart_notes| chart_notes.uniq(&:time).map(&:time) }
      # Index Pointer
      tset = {}
      ctim = Array.new(cary.size) { Hash.new }
      titr = 0
      
      # Find first offset
      -> {
        notes_time = cary.map(&:first)
        actual_time = nary.map(&:first)
        time_shift = 0
        tdiv = [1] * notes_time.size
        begin
          tnotes = notes_time.each_with_index.map{|x,i|Rational(x,tdiv[i]).round(6)}
          # p tnotes.map(&:to_f)
          tlow  = tnotes.min
          thigh = tnotes.max
          tbpm  = bpmize.call(calibrate.call(tlow)).round(2)
          # puts "stop? @#{titr} #{tnotes.map(&:to_f)} #{tbpm.to_f}" if tnotes.all? {|tnow| (tnow - tlow).abs < 1e-6 }
          break if tnotes.all? {|tnow| (tnow - tlow).abs < 1e-6 } if tbpm.denominator <= 1
          
          notes_time.size.times do |cptr|
            tnow = tnotes[cptr]
            tdiv[cptr] += Rational(1,1) if tnow == thigh
          end
        ensure
          titr += 1
        end until titr >= 100000
        time_shift += 4 while actual_time.min < actual_time.max - time_shift * bpmize.call(tbpm)
        time_offset = actual_time.max - time_shift * bpmize.call(tbpm)
        # puts "#{song_id} BPM: #{"%7.3f" % tbpm} @#{"%.3f" % time_offset.round(3)}s (#{titr})"
        setup.store :start_time, time_offset
        tset.store Rational(0), tbpm
      }.call
      next if song_id.to_i < 73
      # Snap timings
      -> {
        toff = setup[:start_time]
        tbpm = tset[Rational(0)]
        tadd = Rational(0)
        tensure = -> (tary) { tary.take_while{|(ntime,time)| !/^[1]{1,2}[0]*$/.match(time.denominator.to_s(2)).nil? } }
        begin
          nary.each{|note_times| note_times.map!{|ntime| [ntime,Rational(ntime - toff,Rational(60,tbpm)).rationalize(1e-3) + tadd] }}
          tchange = false
          nary.each_with_index { |tary,diff|
            mary = tensure.call(tary)
            tchange ||= tary.size != mary.size
            ctim[diff].update tary.shift(mary.size-1).to_h
            ctim[diff].update tary.first(1).to_h
          }
          next if !tchange
          
          -> {
            debut_ticks = 4
            farthest_time = nary.first.first(debut_ticks.succ).last.first
            iptr = [0] * cary.size
            tinv = Array.new(cary.size) { [] }
            
          }.call
          break
        end while tchange
      }.call
      break
    end
  end
  def self.main(*argv)
    new(*argv)
  end if is_main_file
end

def main(*argv); ChartTimeChecker.main(*argv); end if is_main_file
