#!/usr/bin/env ruby

require 'json'
require 'neatjson'
require 'find'
require 'uri'
require 'digest'

require_relative '../lib/framework'
require_relative '../lib/final_class'
require_relative '../lib/deremod'

module ChartAnalyzer;end

class ChartAnalyzer::Parser
  include FinalClass
  def initialize(song_id:,diff_id:)
    @chart_name = "%03d_%1d" % [
      [[(Integer(song_id.to_s,10) rescue 0),999].min,0].max,
      [[(Integer(diff_id.to_s,10) rescue 0),  9].min,0].max
    ]
  end
  def parse
    return @chart_cache if @chart_cache
    
    fn = "charts/%s.json" % @chart_name
    cc = nil
    d = /(\d+)_(\d)/.match(fn)
    ffn = "analyzer/#{d[0]}.chartcache"
    cvd = false
    begin
      cc = Marshal.load(File.read(ffn))
    rescue
      # error
      File.unlink(ffn)
    else
      cvd = Digest::SHA256.file(fn).hexdigest == cc.checksum
    end if File.file?(ffn)
    unless cvd
      c = ImportedChart.load(fn)
      # puts "#{fn} #{c[:chartData].class}"
      cc = c.build(
        difficulty:d[1].to_i,
        hash:Digest::SHA256.file(fn).hexdigest
      )
      File.write(ffn,Marshal.dump(cc))
    end
    @chart_cache = cc
    @chart_cache
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
    new(song_id:argv.shift, diff_id:argv.shift).instance_exec { parse }
  end if is_main_file
end

def main(*argv); ChartAnalyzer::Parser.main(*argv); end if is_main_file
