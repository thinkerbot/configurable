require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable/description'
require 'tempfile'

class DescriptionTest < Test::Unit::TestCase
  Description =  Configurable::Description
  
  def test_description_to_s_resolves_and_returns_trailer
    tempfile = Tempfile.new('desc_test')
    tempfile << %q{
# comment content
1 + 2   # trailer
}
    tempfile.close
    
    doc = Lazydoc::Document.new(tempfile.path)
    desc = doc.register(2, Description)
    
    assert !doc.resolved
    assert_equal doc, desc.document
    assert_equal nil, desc.trailer
    
    assert_equal "trailer", desc.to_s
    assert_equal "trailer", desc.trailer
    assert doc.resolved
  end
end