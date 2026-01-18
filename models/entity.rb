# frozen_string_literal: true

# co_entity
class Entity < ApplicationRecord
  self.table_name = 'co_entity'

  has_one :block, class_name: 'Block::Tile', foreign_key: 'data', inverse_of: 'entity'

  # Scope for finding orphaned entities (no corresponding block with action=3)
  # Uses NOT EXISTS for efficiency with large datasets
  scope :orphaned, lambda {
    block_table = Block.arel_table
    subquery = block_table.project(Arel.sql('1'))
                          .where(block_table[:data].eq(arel_table[:rowid]))
                          .where(block_table[:action].eq(3))
    where(Arel::Nodes::Not.new(Arel::Nodes::Exists.new(subquery)))
  }

  def self.bsearch(low = first, high = last)
    return low unless low && high && !yield(low) && yield(high)

    100.times do
      mid = where(arel_table[:rowid].gteq(low.rowid + (high.rowid - low.rowid) / 2)).first
      return high if low.rowid == mid.rowid || high.rowid == mid.rowid

      if yield(mid)
        high = mid
      else
        low = mid
      end
    end

    raise ActiveRecord::RecordNotFound
  end
end
