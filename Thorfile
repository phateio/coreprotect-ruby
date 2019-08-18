# frozen_string_literal: true

require 'dotenv/load'

# ActiveSupport autoload
require 'active_support'
require 'active_support/core_ext'

# ActiveRecord requirements
require 'erb'
require 'yaml'
require 'active_record'

STDOUT.sync = true
STDERR.sync = true

ActiveSupport::Dependencies.autoload_paths << File.join(Dir.pwd, 'models')

config = YAML.load(ERB.new(IO.read('config/database.yml')).result)
ActiveRecord::Base.establish_connection(config)
ActiveRecord::Base.connection.enable_query_cache!

I18n.load_path << Dir[File.expand_path('config/locales') + '/*.yml']
