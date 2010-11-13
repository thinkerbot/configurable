require 'configurable'
require 'pp'

class ConfigClass
  include Configurable
  
  # Description string.  This can be multi-line and is used in documented
  # config files, or wherever a longer description is appropriate.  The
  # summary is used on the command line (and wherever a short desc is ok).
  # The default will be printed as a 'hint' for users.
  config :option, 'default'       # summary string
  
  config :flag, false
  config :switch, true
  config :integer, 3
  config :float, 3.14
  config :nil
  
  # Lists are identified by an array default. The list type is guessed by
  # first element.
  config :list, []
  config :list_of_int, [1,2,3]
  config :list_of_str, ['a', 'b', 'c']
  
  # Nest configs create a configurable class; the config value is a hash.
  config :outer do
    config :a
    config :b
    config :c
    
    config :inner do
      config :x
      config :y
      config :z
    end
  end
  
  # Options can be specified for any config to provide a whitelist.
  config :select, 1, :options => [1,2,3]
  config :list_select, [1, 3], :options => [1,2,3]
  
  #
  # common variations
  #
  
  # Specify short/long for the command line.
  config :short_long, 'value', :long => :long, :short => :s
  
  # Hide a config from the command line.
  config :hidden, nil, :hidden => true
  
  # Specify the type manually as needed.
  config :manual_list_type, [], :type => :integer
  
  # Specify alternate config types with a name, and matchers.  The matchers
  # will be case-compared against the config value to guess a type.
  config_type(:time, Time).cast do |value|
    Time.at(value.to_i)
  end.uncast do |time|
    time.to_s
  end
  
  # A config using the custom :time type.  Note the default is NOT cast.
  config :custom_type, Time.now
  
  #
  # uncommon variations
  #
  
  # Keys are the actual key in the config.  Keys do not have to be symbols, or
  # even word-based.
  #
  # The config name is used in all places where a word-based identifier is
  # needed.  An alternate name may always be specified but must be specified
  # for non-wordy keys.
  config 0, 'value', :name => 'non_word_symbol_as_key'
  
  # Alternate accessor methods.  If specified (even with the default accesors)
  # then you must define these methods yourself.  Dynamic defaults can be
  # specified in this manner, using memoization on the reader.
  config :alt_reader_writer, nil, :reader => :get_time, :writer => :set_time
  
  def get_time
    @time ||= Time.now
  end
  
  def set_time(value)
    @time = value
  end
  
  # You can set the desc/hint/summary yourself
  config :docs, nil,
    :desc => 'Custom config description',
    :hint => 'null',
    :summary => 'doc example'
end

ConfigClass.configs.to_parser do |psr|
  psr.on('--help') do 
    puts psr
    exit
  end
end.parse(ARGV) do |args, config|
  errors = ConfigClass.configs.validate(config)
  
  if errors.empty?
    pp args
    pp config
  else
    pp errors
  end
end
