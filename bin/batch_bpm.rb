#!/usr/bin/env ruby

require_relative 'chart_bpm'

module ChartAnalyzer
  class BatchAutoBPM
    include FinalClass
    def initialize(song_id:)
      @song_sets = Dir['charts/%s_?.json' % [song_id[0,3].gsub(%r{\D},'?').rjust(3,'0')] ].map { |fn|
        /(\d+)_\d/.match(fn)[1]
      }.sort.uniq.map { |sid|
        AutoBPM.new(song_id:sid)
      }
    end
    def obtain_bpm
      @song_sets.map(&:get_bpm)
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
      argv.each do |arg|
        new(song_id:arg).instance_exec { obtain_bpm }
      end
    end if is_main_file
  end
end

def main(*argv); ChartAnalyzer::BatchAutoBPM.main(*argv); end if is_main_file

