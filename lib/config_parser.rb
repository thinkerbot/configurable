require 'configurable'

class ConfigParser 
  
  attr_reader :options
  
  def separator(str)
    options << str
  end
  
  def on(key, value=nil, options={}, &block)
    klass = case options[:type]
    when :flag then Flag
    when :switch then Switch
    when :list then List
    else Option
    end
    
    register klass.new(key, value, options, &block)
  end
  
  def register(opt)
    return if options.include?(opt)
    
    # check for conflicts
    # options.each do |existing|
    #   if existing.key == opt.key && existing.nesting == opt.nesting
    #     raise "conflict"
    #   end
    # end
    
    opt.longs.each do |long|
      raise if long_options.has_key?(long)
      long_options[long] = opt
    end
    
    opt.shorts.each do |short|
      raise if short_options.has_key?(short)
      short_options[short] = opt
    end
    
    options << opt
  end
  
  # no block allowed?
  # def add(key, configuration)
  #   on(key, configuration.default(false), configuration.attributes)
  # end
  
  def parse(argv=ARGV)
    parse!(argv.dup)
  end
  
  OPTION_BREAK = "--"
  LONG_OPTION = /^--([A-z].*?)(=(.*))?$/  # variants: /^--([^=].*?)(=(.*))?$/
  SHORT_OPTION = /^-([A-z])(=?(.+))?$/
  
  def parse!(argv=ARGV)
    config = {}
    args = []
    
    while !argv.empty?
      arg = argv.shift
      
      # determine if the arg is an option
      unless arg[0] == ?-
        args << arg
        next
      end
      
      # lookup the option
      option = case
      when OPTION_BREAK
        args.concat(argv)
        break
      when LONG_OPTION 
        long_options[$1]
      when SHORT_OPTION 
        short_options[$1]
      else
        nil
      end
      
      unless option
        raise "unknown option: #{arg}"
      end
      
      # determine the value
      # value = case 
      # when option.flag?
      #   raise "value specified for flag" if $3
      #   !option.default
      #   
      # when option.switch?
      #   raise "value specified for switch" if $3
      #   parse_switch($1, option.key, option.default)
      # 
      # when option.list?
      #   parse_list($3 || argv.shift)
      #   
      # else
      #   $3 || argv.shift
      # end
      value = option.parse($1, $3, argv)
      
      # map value into config, collecting values as necessary
      # target = option.nesting.inject(config) {|hash, key| hash[key] ||= {} }
      # if n = option.n
      #   target = (target[option.key] ||= [])
      #   
      #   if option.list?
      #     target.concat(value)
      #   else
      #     target << value
      #   end
      #   
      #   raise "too many specified" unless n < 0 || target.length <= n
      # else
      #   target[option.key] = value
      # end
      
      target = option.target(config)
      option.store(target, key)
    end
    
    # insert default values as necessary and process config values
    config = {}
    options.each do |option|
      next if option.kind_of?(String)
      
      target = option.target(config)
      # target = option.nesting.inject(config) {|hash, key| hash[key] ||= {} }
      
      key = option.key
      value = target.has_key?(key) ? target[key] : option.default
      value = option.block.call(value) if option.block
      
      target[key] = value
    end

    [config, args]
  end
  
  def to_s
    options.collect do |option|
      option.to_s
    end.join("\n")
  end
  
end