=begin
  Framework.rb
=end

END {
  ex = 0
  begin
    main(*ARGV)
  rescue SignalException => se
    STDERR.puts se.backtrace
    Process.kill(se.signo,0)
  rescue SystemExit => se
  rescue Exception => e
    STDERR.puts "#{e.class}: #{e.message}"
    STDERR.puts e.backtrace
    ex = 1
  end
  exit(ex)
}

def is_main_file
  $0 == caller_locations(1,1).first.path
end
