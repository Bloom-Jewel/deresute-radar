=begin
  use this file as the class defining guideline
=end

class ParentClass
  "Class Description"
  # module inclusion
  
  # constants
  
  # class variables
  
  # constructor
  
  # accessors
  public
  
  # private methods
  private
  
  # protected methods
  protected
  
  # public methods
  public
  
  # class methods
  class << self
    # private static methods
    private
    
    # protected static methods
    protected
    
    # public static methods
    public
    
  end
end

class ChildClass < ParentClass
  "Class Description"
  
  # constructor
end

raise NotImplementedError, "classTemplate.rb is not for import or testing"
