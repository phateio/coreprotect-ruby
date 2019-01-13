# frozen_string_literal: true

# co_container
class Container < ApplicationRecord
  self.table_name = 'co_container'
  self.inheritance_column = nil

  belongs_to :world, foreign_key: 'wid', inverse_of: 'containers'
  belongs_to :uzer, class_name: 'user', foreign_key: 'user', inverse_of: 'containers'

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
