#!/usr/bin/env ruby

require 'net/https'
require 'stringio'
require 'json'
require 'neatjson'
require 'find'
require 'uri'

require_relative '../lib/final_class.rb'
require_relative '../lib/deremod.rb'

chart_fetch = Module.new() {
  include FinalClass
  
  class << self
    # Define local-file variable
    cdate    = nil
    listData = {}
    noPurge  = false
    apiURL   = URI('https://apiv2.deresute.info').freeze
    
    define_method(:check_connection) {
      begin
        Net::HTTP.start(apiURL.host,apiURL.port,use_ssl:(apiURL.scheme=='https')) { |http|
          
        }
      rescue Exception => e
        STDERR.puts "Cannot update the chart list, using local data."
        noPurge = true
      end
      !noPurge
    }
    
    define_method(:chart_purge) { |targetDir|
      if Dir.exists?(targetDir)
        Find.find(targetDir) { |pathname|
          basename = File.basename(pathname)
          Find.prune() if basename == 'chart_list.json' ||
            basename.end_with?('_revised.json') ||
            basename =~ /_(?:\d+)[.]json$/ ||
            false
          
          case File.extname(pathname)
          when '.json'
            # Refresh cache after 3 days
            File.unlink(pathname) if cdate > (File.mtime(pathname) + 259200)
          else
            # No extension
            Find.prune()
          end
        }
      else
        Dir.mkdir(targetDir)
      end
      
      nil
    }

    define_method(:fetch_list) { |targetDir|
      listName = File.join(targetDir,'list.json')
      
      unless File.exists?(listName) && cdate <= (File.mtime(listName) + 259200) then
        Net::HTTP.start(apiURL.host,apiURL.port,use_ssl:(apiURL.scheme == 'https')) { |http|
          begin
            reqs = Net::HTTP::Get.new("%s%s" % [apiURL,'/data/live']);
            resp = http.request(reqs);
            resp.value();
            File.write(
              listName,
              JSON.neat_generate(
                JSON.load(resp.body()),
                aligned:true
              )
            );
          rescue => ex
            STDERR.puts "Failed to download song list (#{ex.class}: #{ex.message})"
            exit(1)
          end
        }
      end
      listData = JSON.parse(File.read(listName,encoding:'UTF-8'))
    }

    define_method(:fetch_chart) { |targetDir|
      # Color table
      attrKey  = [7, 1, 4, 3, "9;1"]
      rainKey  = [1,4,3]
      diffKey  = [[7], [4], [3], [1,1], [9,1], [3,1]]
      diffName = ['Null','Debut','Regular','Pro','Master',"Master+"]
      
      listData.reverse.uniq { |songData|
        '%s:%s' % [songData[:musicTitle],songData[:type]]
      }.reverse.each { |songData|
        songKey = "%03d" % songData[:id]
        diffData = songData[:liveDetailId].select( &:nonzero? )
        diffData.each_index { |diffType|
          diffType   = diffType.succ
          chartName  = "#{songKey}_#{diffType}"
          destName   = File.join(targetDir,"#{chartName}.json")
          diffTitle  = "#{songData[:musicTitle]}"
          
          if(songData['type'] == 4)
            diffTitle = diffTitle.each_char.each_with_index.collect { |x,i| "\x1b[3#{rainKey[i % rainKey.length]}m#{x}" }.join('')
            rainKey.rotate!
          end
          diffColor  = "\x1b[3#{attrKey[songData[:type]]}m#{diffTitle}" << 
            "\x1b[0;39m <\x1b[3#{diffKey[diffType].join(';')}m#{diffName[diffType].capitalize}\x1b[39;0m>"
          noDownload = File.exists?(destName)
          if !noDownload then
            begin
              Net::HTTP.start(apiURL.host,apiURL.port,use_ssl:true) { |http|
                reqs = Net::HTTP::Get.new("%s%s%s" % [apiURL.to_s,'/pattern/',chartName])
                resp = http.request(reqs)
                resp.value()
                fail "empty data" if resp.body.empty?
                File.write(
                  destName,
                  JSON.neat_generate(
                    JSON.load(resp.body()),
                    aligned:true,
                    wrap:105
                  ),
                  encoding:'UTF-8'
                )
              }
            rescue => ex
              STDERR.puts("#{diffColor} \x1b[31mfailed to download\x1b[39;0m\n\t(#{ex.class}: #{ex.message})")
              next
            else
              STDERR.puts("#{diffColor} \x1b[32mdownloaded\x1b[39;0m")
            end
          else
            STDERR.puts("#{diffColor} \x1b[32mloaded\x1b[39;0m")
          end
          
          begin
            jsonData   = ImportedChart.load(destName)
            # to note that, parsing the file IS NOT NECESSARY
            # the actual program that should do this instead.
          rescue => ex
            STDERR.puts "#{ex.class}: #{ex.message}"
          end
        }
      }
      
      nil;
    }

    define_method(:main) { |*argv|
      cdate = Time.now()
      
      chartDir = "../data"
      
      check_connection
      if noPurge then
        chart_purge(chartDir)
        fetch_list(chartDir)
        fetch_chart(chartDir)
      end
      
      nil
    }
  end
}

# OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

# Inclusion Check
if __FILE__ == $0
  chart_fetch.main(*ARGV)
else
  $stderr.puts "execute #chartFetchMain to run this"
  define_method(:chart_fetch_main) { |*argv|
    chart_fetch.main(*argv)
  }
end
