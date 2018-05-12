# frozen_string_literal: true

require 'dotenv/load'
require File.expand_path(File.dirname(__FILE__) + '/../models/application_record')
Dir[File.dirname(__FILE__) + '/../models/*.rb'].each { |file| require File.expand_path(file) }

STDOUT.sync = true
STDERR.sync = true
ActiveRecord::Base.connection.enable_query_cache!

QUERY_TIME = Time.now.freeze
START = Integer(ENV['START'] || Block.reorder(rowid: :desc).first.rowid - 100_000_000)
ENDED = Block::Tile.last.rowid - 10_000_000
STEP = 1000

affected_rows = 0

(START..ENDED).step(STEP) do |lbound|
  range = lbound..(lbound + STEP)
  deleted_blocks_size = Block.placed.flows.where(rowid: range).delete_all
  affected_rows += deleted_blocks_size
end

(START..ENDED).step(STEP) do |lbound|
  range = lbound..(lbound + STEP)
  deleted_blocks = Block::Tile.killed.staled.where(rowid: range).destroy_all
  affected_rows += deleted_blocks.size
end

elapsed_time = Time.now - QUERY_TIME.freeze
puts printf('Query OK, %d rows affected (%.2f sec)', affected_rows, elapsed_time)
