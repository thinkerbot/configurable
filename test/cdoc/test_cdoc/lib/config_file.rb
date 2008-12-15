class ConfigFile
  config :key, 'value'       # a basic config
  config :n, 1, &c.integer   # an integer config
end