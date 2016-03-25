#!/usr/bin ruby

require 'net/http'
require 'open-uri'
require 'json'
require 'stringio'
require 'find'

chartFetch = Class.new() {
  class << self
    # Define local-file variable
    cdate    = nil
    listData = {}
    
    define_method(:chartPurge) { |targetDir|
      if Dir.exists?(targetDir)
        Find.find(targetDir) { |pathname|
          basename = File.basename(pathname)
          Find.prune() if basename == 'list.json' ||
            basename.end_with?('_revised.json') ||
            basename =~ /_(?:\d+)[.]json$/ ||
            false
          
          case File.extname(pathname)
          when '.json'
            # Refresh cache after 3 days
            File.unlink(pathname) if cdate > (File.mtime(pathname) + 259200)
          else
            # No extension
            Find.prune();
          end
        }
      else
        Dir.mkdir(targetDir);
      end
      
      nil;
    }

    define_method(:fetchList) { |targetDir|
      listName = "#{targetDir}/list.json";
      listURL  = 'http://cgss.cf/static/list.json';
      
      if File.exists?(listName) && cdate <= (File.mtime(listName) + 259200) then
        listFile = open(listName,"rb");
      else
        begin
          listFile = open(listURL);
          File.open(listName,"wb") { |f|
            f.write(listFile.read());
          }
        rescue => ex
          STDERR.puts "Failed to download song list (#{ex.class}: #{ex.message})"
          exit(1)
        else
          listFile.rewind();
        end
      end
      listData = JSON.parse(listFile.read());
      listFile.close();
      
      nil;
    }

    define_method(:fetchChart) { |targetDir|
      # Color table
      attrKey  = {all:"9;1", cu:1, co:4, pa:3};
      rainKey  = [1,4,3];
      diffKey  = {debut:[4], regular:[3], pro:[1,1], master:[9,1], masterplus:[3,1]}
      
      listData.each_pair { |songKey, songData|
        diffData = songData.select { |dataKey, dataVal|
          dataVal.is_a?(Array) && dataVal.length == 3;
        };
        diffData.each_pair { |diffType, diffItem|
          chartName  = "#{songKey}_#{diffType}";
          destName   = "#{targetDir}/#{chartName}.json";
          diffTitle  = "#{songData['title']}";
          
          if(songData['type'] == 'all')
            diffTitle = diffTitle.each_char.each_with_index.collect { |x,i| "\x1b[3#{rainKey[i % rainKey.length]}m#{x}" }.join('');
            rainKey.rotate!;
          end
          diffColor  = "\x1b[3#{attrKey[songData['type'].to_sym]}m#{diffTitle}" << 
            "\x1b[0;39m <\x1b[3#{diffKey[diffType.to_sym].join(';')}m#{diffType.capitalize}\x1b[39;0m>";
          songFile   = nil;
          noDownload = File.exists?(destName);
          if !noDownload then
            unless diffItem[2]
              STDERR.puts("#{diffColor} \x1b[31mnot available\x1b[39;0m");
              next;
            end
            
            begin
              songFile = open("http://cgss.cf/static/pattern2/#{chartName}.json");
              File.open(destName,"wb") { |f|
                f.write(songFile.read());
                f.write("\r\n");
              };
            rescue => ex
              STDERR.puts("#{diffColor} \x1b[31mfailed to download\x1b[39;0m\n\t(#{ex.class}: #{ex.message})");
              next;
            else
              songFile.rewind();
              STDERR.puts("#{diffColor} \x1b[32mdownloaded\x1b[39;0m");
            end
          else
            songFile = File.open(destName,"rb");
            STDERR.puts("#{diffColor} \x1b[32mloaded\x1b[39;0m");
          end
          
          jsonData   = JSON.parse(songFile.read());
          # to note that, parsing the file IS NOT NECESSARY
          # the actual program that should do this instead.
          songFile.close();
        }
      }
      
      nil;
    }

    define_method(:main) { |*argv|
      cdate = Time.now();

      chartDir = "../../charts";
      
      chartPurge(chartDir)
      fetchList(chartDir)
      fetchChart(chartDir)
      
      nil;
    }
  end
  
  def self.inherited(child)
    fail ScriptError.new(sprintf("Cannot derive class to #{child}"))
  end
}

# Prevent StringIO from OpenURI
OpenURI::Buffer.send(:remove_const, 'StringMax') if OpenURI::Buffer.const_defined?('StringMax')
OpenURI::Buffer.const_set('StringMax', 0);

# Inclusion Check
if __FILE__ == $0
  chartFetch.main(*ARGV)
else
  define_method(:chartFetchMain) { |*argv|
    chartFetch.main(*argv)
  }
end