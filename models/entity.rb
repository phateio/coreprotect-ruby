# frozen_string_literal: true

# co_entity
class Entity < ApplicationRecord
  self.table_name = 'co_entity'

  has_one :block, -> { killed }, foreign_key: 'data', inverse_of: 'entity'
end
