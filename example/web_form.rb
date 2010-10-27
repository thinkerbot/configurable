require 'configurable'
require 'sinatra'

class ConfigClass
  include Configurable
  
  config :checkbox, false
  config :radio, true
  config :str, 'string'
  config :num, 3.14
  config :select, 1, :options => [1,2,3]
end

get '/' do
  configs = ConfigClass.configs.values.sort_by {|config| config.name }
  erb :index, :locals => {:configs => configs}
end

post '/' do
  c = ConfigClass.new
  c.config.import(params)
  
  erb :result, :locals => {:config => c.config}
end

helpers do
  def input_for(config)
    case 
    when config.options
      select_input(config)
    else
      text_input(config)
    end
  end
  
  def select_input(config)
    lines = []
    lines << %Q{<select name="#{config.name}">}
    config.options.each do |option|
      value = config.uncast(option)
      selected = config.default == option ? 'selected="true"' : nil
      lines << %Q{<option value="#{value}" #{selected}>#{value}</option>}
    end
    lines << %Q{</select>}
    lines.join
  end
  
  def text_input(config)
    case config.default
    when true
      %Q{<input type="radio" name="#{config.name}" value="true" checked="true">on</input>
         <input type="radio" name="#{config.name}" value="false">off</input>}
    when false
      %Q{<input type="checkbox" name="#{config.name}" value="true" />}
    else
      %Q{<input type="text" name="#{config.name}" value="#{config.uncast(config.default)}" />}
    end
  end
end

__END__
@@ layout
<html>
<body>
<%= yield %>
</body>
</html>

@@ index
  <form action="/" method="post"><% configs.each do |config| %>
    <label><%= config.name %></label>
    <%= input_for(config) %><br /><% end %>
    <input type="submit" value="Submit" />
  </form>
  
@@ result
  <a href="/">Back</a>
  <pre><%= config.to_hash.inspect %></pre>