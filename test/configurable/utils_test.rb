require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable/utils'

class UtilsTest < Test::Unit::TestCase
  include Configurable::Utils
  
  acts_as_file_test
  
  def prepare(path, obj=nil)
    path = method_root.filepath(:output, path)
    dirname = File.dirname(path)
    FileUtils.mkdir_p(dirname) unless File.exists?(dirname)
    File.open(path, 'w') {|file| file << obj.to_yaml } if obj
    path
  end
  
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
    path = prepare("a.yml", {'key' => 'a value'})
           prepare("a/b.yml", 'b value')
           prepare("a/c.yml", 'c value')
    
    a = {'key' => 'a value', 'b' => 'b value', 'c' => 'c value'}    
    assert_equal(a, load(path))
  end
  
  def test_load_recursively_loads_directories
    path = prepare("a.yml", {'key' => 'value'})
           prepare("a/b/c.yml", 'c value')
           prepare("a/c/d.yml", 'd value')
           
    a = {
       'key' => 'value', 
       'b' => {'c' => 'c value'},
       'c' => {'d' => 'd value'}
    }     
    assert_equal(a, load(path))
  end
  
  def test_recursive_loading_with_files_and_directories
    path = prepare("a.yml", {'key' => 'a value'})
           prepare("a/b.yml", {'key' => 'b value'})
           prepare("a/b/c.yml", 'c value')
           
           prepare("a/d.yml", {'key' => 'd value'})
           prepare("a/d/e/f.yml", 'f value')
    
    d = {'key' => 'd value', 'e' => {'f' => 'f value'}}   
    b = {'key' => 'b value', 'c' => 'c value'}   
    a = {'key' => 'a value', 'b' => b, 'd' => d}
    
    assert_equal(a, load(path))
  end
  
  def test_recursive_loading_sets_value_for_each_hash_in_a_parent_array
    path = prepare("a.yml", [{'key' => 'one'}, {'key' => 'two'}])
           prepare("a/b.yml", 'b value')
           
    a = [
      {'key' => 'one', 'b' => 'b value'},
      {'key' => 'two', 'b' => 'b value'}]
            
    assert_equal(a, load(path))
  end
  
  def test_recursive_loading_with_files_and_directories_and_arrays
    path = prepare("a.yml", [{'key' => 'a one'}, {'key' => 'a two'}])
           prepare("a/b.yml", [{'key' => 'b one'}, {'key' => 'b two'}])
           prepare("a/b/c.yml", 'c value')
           
           prepare("a/d.yml", [{'key' => 'd one'}, {'key' => 'd two'}])
           prepare("a/d/e/f.yml", 'f value')
    
    d = [
      {'key' => 'd one', 'e' => {'f' => 'f value'}}, 
      {'key' => 'd two', 'e' => {'f' => 'f value'}}]
    b = [
      {'key' => 'b one', 'c' => 'c value'}, 
      {'key' => 'b two', 'c' => 'c value'}]
    a = [
      {'key' => 'a one', 'b' => b, 'd' => d}, 
      {'key' => 'a two', 'b' => b, 'd' => d}]
    
    assert_equal(a, load(path))
  end
  
  def test_load_with_symbolize_symbolizes_all_hash_keys
    path = prepare("a.yml", [{'key' => 'one'}, {'key' => 'two'}])
           prepare("a/b.yml", 'b value')
           prepare("a/c.yml", {'key' => 'value'})
           
    a = [
      {:key => 'one', :b => 'b value', :c => {:key => 'value'}},
      {:key => 'two', :b => 'b value', :c => {:key => 'value'}}]
            
    assert_equal(a, load(path, true, true))
  end
  
  def test_recursive_loading_does_not_override_values_set_in_parent
    path = prepare("a.yml", {'a' => 'set value', 'b' => 'set value'})
           prepare("a/b.yml", 'recursive value')
           prepare("a/c.yml", 'recursive value')
           
    a = {
      'a' => 'set value',
      'b' => 'set value',
      'c' => 'recursive value'
    }
    
    assert_equal(a, load(path))
  end
  
  def test_load_does_not_recursively_load_over_single_values
    path = prepare("a.yml", 'single value')
           prepare("a/b.yml", 'b value')  
    
    assert_equal('single value', load(path))
  end
  
  def test_load_does_not_recusively_load_unless_specified
    path = prepare("a.yml", {'key' => 'a value'})
           prepare("a/b.yml", {'key' => 'ab value'})
           
    a = {'key' => 'a value'}
            
    assert_equal(a, load(path, false))
  end
  
  def test_recursive_loading_raises_error_when_two_files_map_to_the_same_value
    path = prepare("a.yml", {})
    one  = prepare("a/b.yml", 'one')
    two  = prepare("a/b.yaml", 'two')  
           
    e = assert_raise(RuntimeError) { load(path) }
    assert_equal "multiple files load the same key: [\"b.yaml\", \"b.yml\"]", e.message
  end
end