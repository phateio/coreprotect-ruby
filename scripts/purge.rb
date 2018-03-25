# frozen_string_literal: true

require 'dotenv/load'
require File.expand_path(File.dirname(__FILE__) + '/../models/application_record')
Dir[File.dirname(__FILE__) + '/../models/*.rb'].each { |file| require File.expand_path(file) }

@world_2014_the_end = World.find_by!(world: 'world_2014_the_end')
@world_2017_the_end = World.find_by!(world: 'world_2014_the_end')

@fire = User.find_by!(user: '#fire')
@water = User.find_by!(user: '#water')
@lava = User.find_by!(user: '#lava')
@creeper = User.find_by!(user: '#creeper')

@entity_creeper = EntityMap.find_by!(entity: 'creeper')
@entity_enderman = EntityMap.find_by!(entity: 'enderman')

def to_delete?(record)
  return true if record.wid.eql?(@world_2014_the_end.id) && record.type.eql?(@entity_enderman.id)
  return true if record.wid.eql?(@world_2017_the_end.id) && record.type.eql?(@entity_enderman.id)
  return true if record.user.eql?(@creeper.rowid) && record.type.eql?(@entity_creeper.id)
end

affected_rows = 0
query_time = Time.now
end_time = Integer(3.days.ago)

flows = Block.arel_table[:user].in([@fire, @water, @lava])
start = ENV['START'] || Block.reorder(rowid: :desc).first.rowid - 100_000_000

Block::Tile.killed.find_each(start: start) do |block|
  next unless to_delete?(block)
  block.destroy
  affected_rows += 1
  break if block.time > end_time
end

Block.placed.where(flows).find_each(start: start) do |block|
  block.destroy
  affected_rows += 1
  break if block.time > end_time
end

elapsed_time = Time.now - query_time
puts printf('Query OK, %d rows affected (%.2f sec)', affected_rows, elapsed_time)
