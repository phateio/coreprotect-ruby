# frozen_string_literal: true

require 'pry'

desc 'Prompt runtime developer console'
task :irb do
  binding.respond_to?(:irb) && binding.irb || binding.pry
end
