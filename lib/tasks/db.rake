# frozen_string_literal: true

namespace :db do
  desc 'Create the database'
  task :create do
    ActiveRecord::Base.connection.create_database(database)
    puts 'Database created.'
  end

  desc 'Migrate the database'
  task :migrate do
    ActiveRecord::Migrator.migrate('db/migrate/')
    Rake::Task['db:schema'].invoke
    puts 'Database migrated.'
  end

  desc 'Drop the database'
  task :drop do
    ActiveRecord::Base.connection.drop_database(database)
    puts 'Database deleted.'
  end

  desc 'Reset the database'
  task reset: %i[drop create migrate]

  desc 'Create a db/schema.rb file that is portable against any DB supported by AR'
  task :schema do
    require 'active_record/schema_dumper'
    filename = 'db/schema.rb'
    File.open(filename, 'w:utf-8') do |file|
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
    end
  end

  def database
    ActiveRecord::Base.connection.current_database
  end
end
