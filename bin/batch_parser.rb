#!/usr/bin/env ruby

require_relative 'chart_parser'

module ChartAnalyzer
  class BatchParser
    include FinalClass
    def initialize(song_id:)
      @parsers = Dir[("charts/%s_?.json" % song_id[0,3].gsub(%r{\D},'?').rjust(3,'0'))].sort.map do |chart_name|
        lid,did = /(\d{3})_(\d)/.match(chart_name).values_at(1,2)
        Parser.new(song_id: lid, diff_id: did)
      end
    end
    def parse
      @parsers.map(&:parse)
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
      new(song_id:argv.shift).instance_exec { parse_charts }
    end if is_main_file
  end
end

def main(*argv); ChartAnalyzer::BatchParser.main(*argv); end if is_main_file
