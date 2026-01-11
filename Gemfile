# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

ruby '>= 3.1.0'

gem 'bigdecimal', '~> 3.1.0'
gem 'dotenv'
gem 'activerecord', '~> 7.2.0'
gem 'activesupport', '~> 7.2.0'
gem 'mysql2'
gem 'i18n'
gem 'thor'
gem 'pry'

group :development do
  gem 'rubocop', require: false
end
