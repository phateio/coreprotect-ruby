# frozen_string_literal: true

namespace :block do
  desc 'Purge blocks from the database'
  task :purge do
    EXPIRED_TIME = Integer(1.month.ago)
    block_id = Block.built.bsearch { |block| block.time > EXPIRED_TIME }.rowid

    puts format('Estimated %d rows to be deleted', block_id - Block.built.first.rowid)
    if ActiveRecord::Type::Boolean.new.type_cast_from_user(ENV['DELETE'])
      legacy_blocks = Block.arel_table[:rowid].lt(block_id)
      Block.built.where(legacy_blocks).find_in_batches(&:delete_all)
    end
  end
end
