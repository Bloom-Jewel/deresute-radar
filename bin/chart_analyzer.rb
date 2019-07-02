#!/usr/bin/env ruby

require_relative 'chart_parser'
require_relative 'chart_bpm'

class Radar
  Categories = {
    stream: ->(c){
      60 * Rational(c[:note_count],c[:chart_length]) * Rational(2,3)
    },
    voltage:->(c){
      Rational(c[:peak_density] * c[:average_time],4) * Rational(2,9)
    },
    freeze: ->(c){
      1000 * Rational(c[:hold_length],c[:chart_length]) * Rational(30,100)
    },
    slide:  ->(c){
      60 * Rational(c[:slide_length] + Rational(
        [
          Rational(c[:flick_count] * 1,12),
          Rational(c[:slide_kicks] * 1, 2),
          Rational(c[:slide_power] * 6, 4)
        ].inject(:+),
        1
      ),c[:chart_length]) * Rational(5,4)
    },
    air:    ->(c){
      60 * Rational(c[:pair_count],c[:chart_length]) * Rational(4,3)
    },
    chaos:  ->(c){
      tbpm = Rational(60 * c[:chaos_time],c[:song_length])
      ird  = [c[:chaos_base] - 0,0.0].max * (1.0 + Rational(tbpm, 700))
      ipd  = [c[:chaos_pair] - 0,0.0].max * (1.0 + Rational(tbpm, 500))
      Rational(48 * (ird + ipd),c[:song_length])
    }
  }.freeze
  
  def initialize
    @counter = Hash.new { |h,k|
      k = k.to_s.to_sym
      if h.has_key? k then
        h[k]
      else
        h[k] = 0.0
      end
    }
  end
  def [](key)
    @counter[key]
  end
  def []=(key,value)
    @counter[key] = Float(value) rescue value.to_f
  end
  
  def inspect
    "#<%s:%#016x %s>" % [
      self.class,
      self.__id__,
      to_s
    ]
  end
  def to_s
    Categories.map { |r,f|
      "%s:%7.3f" % [r,f.call(@counter)]
    }.join(' ')
  end
  def values_at(*keys)
    @counter.values_at(*keys)
  end
  
  Categories.each do |radar,formula|
    define_method "raw_#{radar}" do
      formula.call @counter
    end
  end
end

module ChartAnalyzer; class Analyzer
  include FinalClass
  def initialize(song_id:,diff_id:)
    @song_id, @diff_id = [
      [[(Integer(song_id,10) rescue 0),999].min,0].max,
      [[(Integer(diff_id,10) rescue 0), 99].min,0].max
    ]

    @parser = Parser.new(song_id: @song_id, diff_id: @diff_id)
    @chart  = @parser.parse
    @bpm    = AutoBPM.new(song_id: @song_id)
    @radar  = Radar.new
    
    @bpm.get_bpm
  end
  
  def analyze
    n = chart.notes.values
    h = chart.holds.values
    s = chart.slides.values
    j = chart.pairs
    
    # Determine the actual value first
    radar[:pair_count]   = j.size
    radar[:hold_count]   = h.size
    radar[:slide_count]  = s.size
    radar[:flick_count]  = n.count{|nn|nn.is_a? FlickNote}
    radar[:shold_count]  = n.count{|nn|nn.is_a? SlideNote}
    radar[:combo_count]  = n.size
        
    np = n.select{|nn|nn.is_a? TapNote}
    # Find pure non hold notes
    h.map { |ho| ho[0..-1] }.flatten.each { |nnp| np.delete(nnp) }
    # Normalize intense slide (hold abuse)
    s.each do |sl|
      next unless sl.first.is_a? SlideNote
      delete_list = []
      (0...sl.size).each do |si1|
        sn1 = sl[si1]
        next if delete_list.include?(sn1)
        next unless sn1.is_a? SlideNote
        hold_data = []
        ((si1+1)...sl.size).each do |si2|
          sp2 = sl[si2.pred]
          sn2 = sl[si2]
          next if delete_list.include?(sn2)
          if si2.succ == sl.size || sn1.pos != sn2.pos || !sn2.is_a?(SlideNote) then
            if sn1.pos == sp2.pos && si1 < si2.pred then
              #puts [si1,si2].to_s
              hold_data.concat sl[*(si1..si2.pred).to_a]
            end
            break
          end
          next unless sn2.is_a? SlideNote
        end
        hold_data.pop
        hold_data.shift
        next if hold_data.size <= 2
        delete_list.concat hold_data
        hold_data.clear
      end
      delete_list.each do |item|
        n.delete(item)
      end
      delete_list.clear
    end
    
    # Stream/Air
    radar[:note_count]   = np.size
    radar[:song_length]  = n.map(&:time).max
    radar[:chart_length] = [:max,:min].map{|m| n.map(&:time).send(m)}.reduce(:-)
    
    # Freeze
    radar[:hold_length] = 0.0
    -> {
      hp = proc { |ho| [ho.start.time,(ho.end.time - ho.start.time).round(6)] }
      hs = h.map(&hp)
      hs += s.map(&:truncate).compact.map(&hp)
      hs.group_by { |(start_time,hold_duration)| start_time }
        .map { |start_time,timeset| [start_time,timeset.map(&:last).max] }
        .tap { |holds| radar[:hold_length] = holds.map(&:last).inject(:+) }
    }.call
    
    # Slide
    radar[:slide_kicks] = 0
    radar[:slide_power] = 0
    
    sp = h.map(&:end).select{|nn|nn.is_a? FlickNote}
    s.each do |slide|
      so = slide[0..-1]
      
      # Find flick that is not slides
      sp.delete(so.first)
      
      slide_length = 0.0
      #radar[:flick_count] += so.size
      slide_kicks  = [
        so.inject([nil,nil,0]) { |memo,flick|
          case flick
          when SlideNote
            slide_length += flick.time - memo[1].time if memo[1] && flick.pos != memo[1].pos
          when FlickNote
            case memo[1]
            when FlickNote
              if memo[0] != flick.param
                memo[0] = flick.param
                memo[-1]+= 1
              end
            else
              memo[0] = flick.param
            end
            slide_length += flick.time - memo[1].time if memo[1]
          end
          memo[1] = flick
          
          memo
        }.last - 1,
        0
      ].max
      radar[:slide_kicks]  += slide_kicks
      radar[:slide_length] += slide_length
      slide_chain_power  = [so.size + slide_kicks - 5,0].max * 0.025
      slide_length_power = (1 + slide_length) ** 0.80
      radar[:slide_power] += ((slide_chain_power + 1) * (slide_length_power)) ** 0.90
    end
    
    n.map{|note|[note.time,note.class]}.sort_by(&:first).map{|(time,type)|[@bpm.mapped_time[time],type]}.tap do |timeset|
      timeset.map(&:first).compact.each_cons(2).map{|(x,y)|y-x}.tap do |times|
        # Voltage
        zt = times.dup
        xt = []
        radar[:average_time] = Rational(60 * Rational(times.inject(:+)),radar[:chart_length]).rationalize(1e-4)
      
        while !zt.empty?
          xt.shift if !xt.empty? # && xt.inject(:+)
          xt.push(zt.shift) while !zt.empty? && (xt.last.nil? || (xt.inject(:+)+zt.first.to_f) <= 4)
          radar[:peak_density] = [radar[:peak_density] || 0,xt.size].max
        end
      end
      timeset.tap do |times|
        # Chaos
        first_time = times.first.first
        
        radar[:chaos_base] = times.inject(Rational(0)) do |irv, (chaos_time,chaos_type)|
          ir = 0
          case chaos_time.denominator
          when 1
            ir += 0
          when 2, 4, 8
            ir += 0.25 * chaos_time.denominator
          when 3, 6
            ir += 0.15 * chaos_time.denominator
          else
            ir += 1.25
          end if chaos_time > first_time
          ir *= 0.5 if chaos_type == FlickNote
          #last_chaos = chaos_type
          irv + ir
        end
        radar[:chaos_pair] = j.inject(0) do |ipv, pair_set|
          ip = 0
          pn = pair_set.start,pair_set.end
          ps = pn.size.times.map { |i| pn[i].pos + (pn[i].is_a?(FlickNote) ? (pn[i].param <=> 1.5)*0.5 : 0) }
          ip += (2 ** (2 - (ps[1] - ps[0]).abs) )
          ipv + (ip >= 1 ? ip : 0)
        end
        radar[:chaos_time] = @bpm.timing_set.values.each_cons(2).inject(0){ |ibv,(bpm1,bpm2)| ibv + (bpm2 - bpm1).abs }
      end.clear
      timeset.clear
    end
    
    # puts "%s_%s n:%3d h:%3d s:%3d p:%3d %s" % [song_id,diff_id,n.size,h.size,s.size,j.size,radar]
    puts "%s_%s voltage:%7.3f average:%7.3f dense:%d" % [song_id,diff_id,radar.raw_voltage,radar[:average_time],radar[:peak_density]]
    # puts "%s_%s slide:%9.3f count:%3d/%3d kicks:%3d power:%9.3f" % [song_id,diff_id,radar.raw_slide,radar[:flick_count],radar[:shold_count],radar[:slide_kicks],radar[:slide_power]]
    puts "%s_%s chaos:%7.3f base:%7.3f pair:%7.3f time:%7.3f" % [song_id,diff_id,radar.raw_chaos,radar[:chaos_base],radar[:chaos_pair],radar[:chaos_time]]
  end
  
  def update
    require 'bjp/common'
    update_mysql do |db|
      res = []
      Radar::Categories.keys.each do |cat|
        res << radar.send("raw_#{cat}").to_f
      end
      res.push(*radar.values_at(
        :note_count,  :hold_count,  :pair_count,
        :flick_count, :slide_count, :shold_count,
        :combo_count, :song_length
      ))
      res.push @song_id,@diff_id
      db.prepare(
        "UPDATE deresute_charts " +
        "SET " + 
        "r_stream = ?, r_voltage = ?, r_freeze = ?, r_slide = ?, r_air = ?, r_chaos = ?, " +
        "count_notes = ?, count_holds = ?, count_syncs = ?, count_flicks = ?, count_slides = ?, count_sholds = ?, count_combos = ?," +
        "song_length = ? " +
        "WHERE chartset_id = ? AND difficulty = ?"
      ).execute(*res)
    end
  end
  
  def update_sqlite3(&block)
    BloomJewel.sqlite3(:website,:production,&block)
  rescue SQLite3::BusyException => sqbe
    sleep 1.0
    retry
  rescue Exception => e
    STDERR.puts "Ignoring Database... (#{e.class}: #{e.message})"
  end
  
  def update_mysql(&block)
    BloomJewel.mysql(:website,:production,&block)
  end
  
  def method_missing(m,*a,&b)
    if instance_variable_defined?("@#{m}") then
      self.class.class_exec { define_method("#{m}") { instance_variable_get("@#{m}") } }
      send m
    else
      super(m,*a,&b)
    end
  end
  def self.main(*argv)
    new(song_id: argv.shift, diff_id: argv.shift).instance_exec { analyze; update }
  end if is_main_file
end; end

def main(*argv); ChartAnalyzer::Analyzer.main(*argv); end if is_main_file

