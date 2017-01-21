#!/usr/bin/env ruby

require 'json'
require 'neatjson'
require 'find'
require 'uri'
require 'digest'

require_relative '../lib/framework'
require_relative '../lib/final_class'
require_relative '../lib/deremod'

class ChartParser
  include FinalClass
  def initialize(*argv)
    @charts = if $DEBUG then
                [
                  "510_1.json","515_2.json","504_2.json","509_3.json","520_3.json","518_3.json",
                  "502_4.json","508_4.json","516_4.json","511_4.json","523_4.json","519_4.json"
                ].map { |x| "charts/#{x}" }
              else
                Dir['charts/???_?.json'].sort
              end
  end
  def parse_charts
    @charts.map { |fn|
      cc = nil
      d = /(\d+)_(\d)/.match(fn)
      ffn = "charts/#{d[0]}.chartcache"
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
        cc = c.build(
          difficulty:d[1].to_i,
          hash:Digest::SHA256.file(fn).hexdigest
        )
        File.write(ffn,Marshal.dump(cc))
      end
      [d[1],cc]
    }.group_by { |(stype,chart)| stype }
     .map { |stype,chart| [stype,chart.map(&:last)] }
     .to_h
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
    new(*argv).instance_exec {
      parse_charts
    }
  end if is_main_file
end

def main(*argv); ChartParser.main(*argv); end if is_main_file
