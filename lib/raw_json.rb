=begin
  RawJSON.rb
  
  Raw JSON handler
=end

require_relative 'kernel_snippet'

# INCLUSION LINE STARTS HERE
class RawJSON
  "Representing an immutable raw imported data from cgss.cf"
  include Enumerable
  
  # constructor
  def initialize(hash={})
    @raw = {}
    @raw.replace(hash) rescue @raw
    @raw.freeze
  end
  
  # accessor
  public
  def [](*keys)
    cptr = @raw
    begin
      cptr = cptr[keys.shift()]
    end until keys.empty? || !(cptr.is_a?(Enumerable) && cptr.respond_to?(:[]))
    cptr.dup() rescue cptr
  end
  
  def has_key?(key)
    @raw.has_key? key
  end
  
  # public methods
  public
  def each(&block)
    @raw.each(&block)
  end
  def to_str; @raw.to_s; end
  def to_hash; @raw.dup(); end
  
  alias :inspect :to_str
  alias :to_s    :to_str
  alias :to_h    :to_hash
  
  # Added JSON support
  def as_json(*)
    @raw
  end
  
  def to_json(*args)
    as_json.to_json(*args)
  end
    
  class << self
    def json_create(object)
      new(object)
    end
    
    def load(filename)
      if Object.const_defined?('JSON')
        new({chartData:JSON.load(File.read(filename,encoding:'UTF-8'))})
      end
    end
  end
  
  if Object.const_defined?('JSON')
    JSON.load_default_options.instance_exec do
      delete(:create_additions)
      merge!({
        symbolize_names: true
      })
    end
  end
  
  GlobalConstDeclare(self);
end

# INCLUSION LINE ENDS HERE

if __FILE__ == $0 then
  puts("Loaded main module.")
else
  # puts("Included #{__FILE__} module")
end
