require File.expand_path('../tap_test_helper.rb', __FILE__) 
require 'fileutils'

class CDocTest < Test::Unit::TestCase
  
  def setup
    @current_dir = File.expand_path(Dir.pwd)
    @root_dir = File.expand_path(File.dirname(__FILE__) + "/cdoc/#{name}")
    Dir.chdir(@root_dir)
  end
  
  def teardown
    rdoc_dir = @root_dir + "/html"
    FileUtils.rm_r(rdoc_dir) if passed? && File.exists?(rdoc_dir)
    Dir.chdir(@current_dir)
  end
  
  def test_cdoc
    system('rake rdoc -s')
    expected_dir = File.expand_path("expected")
    Dir.glob("#{expected_dir}/**/*.html").each do |expected|
      actual = "html" + expected[expected_dir.length..-1]
      assert FileUtils.cmp(expected, actual), "not equal: #{expected}"
    end
  end
end