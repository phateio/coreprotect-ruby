# frozen_string_literal: true

# co_entity_map
class EntityMap < ApplicationRecord
  self.table_name = 'co_entity_map'

  has_many :blocks, foreign_key: 'type', inverse_of: 'entity_map'
end
