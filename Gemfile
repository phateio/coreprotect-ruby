# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

ruby '>= 2.0.0'

gem 'dotenv'
gem 'activerecord'
gem 'activesupport'
gem 'mysql2'
gem 'pry'

group :development do
  gem 'rubocop', require: false
end
