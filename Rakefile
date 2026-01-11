# frozen_string_literal: true

require 'dotenv/load'

# ActiveSupport autoload
require 'active_support'
require 'active_support/core_ext'

# ActiveRecord requirements
require 'erb'
require 'yaml'
require 'active_record'

$stdout.sync = true
$stderr.sync = true

config = YAML.load(ERB.new(File.read('config/database.yml')).result)
ActiveRecord::Base.establish_connection(config)
ActiveRecord::Base.connection.enable_query_cache!
ActiveRecord::Base.logger = Logger.new($stdout)

# Load models explicitly (ActiveSupport 7.x removed classic autoloader)
require File.expand_path('models/application_record', __dir__)
Dir[File.expand_path('models/*.rb', __dir__)].each { |file| require file }

Rake.add_rakelib 'lib/tasks'

I18n.load_path << Dir["#{File.expand_path('config/locales')}/*.yml"]
