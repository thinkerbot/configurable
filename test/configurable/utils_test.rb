require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable/utils'

class UtilsTest < Test::Unit::TestCase
  include Configurable::Utils
  
  acts_as_file_test
  
  #
  # load test
  #
  
  def test_load_returns_empty_array_for_non_existant_file
    path = method_root.filepath("non_existant.yml")
    assert !File.exists?(path)
    assert_equal({}, load(path))
  end
  
  def test_load_returns_empty_array_for_empty_file
    path = method_tempfile("non_existant.yml") {}
    
    assert File.exists?(path)
    assert_equal "", File.read(path)
    assert_equal({}, load(path))
  end
  
  def test_load_loads_existing_files_as_yaml
    path = method_tempfile("file.yml") {|file| file << {'key' => 'value'}.to_yaml }
    assert_equal({'key' => 'value'}, load(path))
    
    path = method_tempfile("file.yml") {|file| file << [1,2].to_yaml }
    assert_equal([1,2], load(path))
  end
  
  def test_load_recursively_loads_files
    path = method_root.filepath("a.yml")
    
    d = {'key' => 'abcd value'}
    c = {'d' => d}
    b = {'key' => 'ab value', 'c' => c}
    a = {'key' => 'a value', 'b' => b}
            
    assert_equal(a, load(path))
  end
  
  def test_load_does_not_recusively_load_unless_specified
    path = method_root.filepath("a.yml")
    a = {'key' => 'a value'}
            
    assert_equal(a, load(path, false))
  end
  
end