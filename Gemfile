# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

ruby '2.3.3'

gem 'dotenv'
gem 'activerecord'
gem 'activesupport'
gem 'mysql2'
gem 'pry'

group :development do
  gem 'unicode-display_width', '1.3.0'
  gem 'rubocop', '~> 0.50.0', require: false
end
