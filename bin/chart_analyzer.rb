#!/usr/bin/env ruby

require_relative 'chart_parser'
# require_relative 'chart_bpm'

class Radar
  Categories = {
    stream: ->(c){
      60 * Rational(c[:note_count],c[:chart_length]) * Rational(2,3)
    },
    voltage:->(c){
      Rational(c[:natural_time] * (Math.log(c[:peak_density],3) + 3),4) * Rational(4,5)
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
      0
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
    @counter[key] = Float(value)
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
      [[(Integer(diff_id,10) rescue 0),  9].min,0].max
    ]

    @parser = Parser.new(song_id: @song_id, diff_id: @diff_id)
    @chart  = @parser.parse
    @radar  = Radar.new
  end
  
  def analyze
    volt_length = 1.0
    
    n = chart.notes.values
    h = chart.holds.values
    s = chart.slides.values
    j = chart.pairs
    
    np = n.select{|nn|nn.is_a? TapNote}
    # Find pure non hold notes
    h.map { |ho| ho[0..-1] }.flatten.each { |nnp| np.delete(nnp) }
    
    # Stream/Air
    radar[:note_count]   = np.size
    radar[:pair_count]   = j.size
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
    radar[:hold_count]  = h.size
    
    # Slide
    radar[:shold_count] = 0
    radar[:flick_count] = 0
    radar[:slide_count] = 0
    radar[:slide_kicks] = 0
    radar[:slide_power] = 0
    
    sp = h.map(&:end).select{|nn|nn.is_a? FlickNote}
    s.each { |slide|
      so = slide[0..-1]
      
      # Find flick that is not slides
      sp.delete(so.first)
      
      radar[:flick_count] += so.size
      radar[:slide_kicks] += [
        so.inject([nil,nil,0]) { |memo,flick|
          case flick
          when SuperNote
            radar[:shold_count] += 1
          when FlickNote
            case memo[1]
            when FlickNote
              if memo[0] != flick.dir
                memo[0] = flick.dir
                memo[-1]+= 1
              end
            else
              memo[0] = flick.dir
            end
          end
          memo[1] = flick
          
          memo
        }.last - 1,
        0
      ].max
      radar[:slide_length] += slide.end.time - slide.start.time
      slide_chain_power  = [radar[:flick_count] + radar[:slide_kicks] - 5,0].max * 0.025
      slide_length_power = (1 + radar[:slide_length]) ** 0.80
      radar[:slide_power] += ((slide_chain_power + 1) * (slide_length_power)) ** 0.90
    }
    radar[:slide_count] = s.size
    radar[:flick_count] += sp.size
    
    # Voltage
    n.map(&:time).sort.tap { |times|
      zt = times.dup
      xt = []
      ct = n.select{|x|x.is_a? TapNote}.map(&:time).uniq.sort.each_cons(2).map { |(x,y)| (y-x).round(6) }
      radar[:common_time]  = ct.group_by{|x|x}.map{|k,v|[k,v.size]}.max{|x|x.last}.first
      radar[:average_time] = ct.inject(:+).fdiv(ct.size)
      [radar[:common_time],radar[:average_time]].tap { |(a,b)|
        a,b = b,a if b < a
        radar[:natural_time] = Rational(60,a + (b - a) * 0.3)
      }
      
      radar[:peak_density] = times.uniq.map{|time|
        xt.shift while !xt.empty? && xt.first < time
        xt.push zt.shift while !zt.empty? && (xt.last.nil? || xt.last < time+volt_length)
        xt.size
      }.max
    }
    
    radar[:combo_count] = n.size
    
    # puts "%s_%s n:%3d h:%3d s:%3d p:%3d %s" % [song_id,diff_id,n.size,h.size,s.size,j.size,radar]
    # puts "%s_%s voltage:%7.3f common:%7.3f average:%7.3f natural:%7.3f dense:%d" % [song_id,diff_id,radar.raw_voltage,radar[:common_time],radar[:average_time],radar[:natural_time],radar[:peak_density]]
    # puts "%s_%s slide:%9.3f count:%3d/%3d kicks:%3d power:%9.3f" % [song_id,diff_id,radar.raw_slide,radar[:flick_count],radar[:shold_count],radar[:slide_kicks],radar[:slide_power]]
  end
  
  def update
    require 'sqlite3'
    SQLite3::Database.new File.join(ENV['HOME'],'pre-saijue','db','production.sqlite3') do |db|
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
      db.execute(
        "UPDATE deresute_charts " +
        "SET " + 
        "r_stream = ?, r_voltage = ?, r_freeze = ?, r_slide = ?, r_air = ?, r_chaos = ?, " +
        "count_notes = ?, count_holds = ?, count_syncs = ?, count_flicks = ?, count_slides = ?, count_sholds = ?, count_combos = ?," +
        "song_length = ? " +
        "WHERE chartset_id = ? AND difficulty = ?",
        *res
      )
    end
  rescue Exception => e
    STDERR.puts "Ignoring Database... (#{e.class}: #{e.message})"
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

