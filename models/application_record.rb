# frozen_string_literal: true

require 'yaml'
require 'erb'
require 'active_record'

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

config = YAML.load(ERB.new(IO.read('config/database.yml')).result)
ActiveRecord::Base.establish_connection(config)
ActiveRecord::Base.logger = Logger.new(STDOUT)
