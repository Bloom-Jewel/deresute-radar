#!/usr/bin ruby

require 'net/http'
require 'open-uri'
require 'json'
require 'stringio'
require 'find'

# Prevent StringIO from OpenURI
OpenURI::Buffer.send :remove_const, 'StringMax' if OpenURI::Buffer.const_defined?('StringMax')
OpenURI::Buffer.const_set 'StringMax', 0

def main(*argv)
  cdate = Time.now;

  attrKey  = {all:9, cu:1, co:4, pa:3};
  diffKey  = {debut:[4], regular:[3], pro:[1,1], master:[9,1], masterplus:[3,1]}
  chartDir = "../../charts";
  listURL  = 'http://cgss.cf/static/list.json';

  listName = "#{chartDir}/list.json";

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

  if Dir.exists?(chartDir)
    Find.find(chartDir) { |pathname|
      case File.extname(pathname)
      when '.json'
        # Refresh cache after 3 days
        File.unlink(pathname) if cdate > (File.mtime(pathname) + 259200)
      else
        # No extension
        Find.prune
      end
    }
  else
    Dir.mkdir(chartDir);
  end

  listData.each_pair { |songKey, songData|
    diffData = songData.select { |dataKey, dataVal|
      dataVal.is_a?(Array) && dataVal.length == 3;
    }
    diffData.each_pair { |diffType, diffItem|
      chartName  = "#{songKey}_#{diffType}";
      destName   = "#{chartDir}/#{chartName}.json";
      diffTitle  = "#{songData['title']}";
      diffColor  = "\x1b[3#{attrKey[songData['type']]}m#{diffTitle}" << 
        "\x1b[0;39m <\x1b[3#{diffKey[diffType.to_sym].join(';')}m#{diffType.capitalize}\x1b[0;39m>";
      songFile   = nil;
      noDownload = File.exists?(destName);
      if !noDownload then
        unless diffItem[2]
          STDERR.puts "#{diffColor} \x1b[31mnot available\x1b[0;39m"
          next
        end
        
        begin
          songFile = open("http://cgss.cf/static/pattern2/#{chartName}.json");
          File.open(destName,"wb") { |f|
            f.write(songFile.read());
            f.write("\r\n");
          }
        rescue => ex
          STDERR.puts "#{diffColor} \x1b[31mfailed to download\x1b[0;39m\n\t(#{ex.class}: #{ex.message})"
          next
        else
          songFile.rewind();
          STDERR.puts "#{diffColor} \x1b[32mdownloaded\x1b[0;39m"
        end
      else
        songFile = File.open(destName,"rb");
        STDERR.puts "#{diffColor} \x1b[32mloaded\x1b[0;39m"
      end
      
      jsonData   = JSON.parse(songFile.read());
      # to note that, parsing the file IS NOT NECESSARY
      # the actual program that should do this instead.
      songFile.close();
    }
  }
end

main(*ARGV)