# frozen_string_literal: true

# co_block
class Block < ApplicationRecord
  self.table_name = 'co_block'
  self.inheritance_column = nil

  belongs_to :world, foreign_key: 'wid', inverse_of: 'blocks'
  belongs_to :uzer, class_name: 'user', foreign_key: 'user', inverse_of: 'blocks'

  scope :removed, -> { where(action: 0) }
  scope :placed, -> { where(action: 1) }
  scope :clicked, -> { where(action: 2) }
  scope :killed, -> { where(action: 3) }

  class Tile < Block
    default_scope { killed }

    belongs_to :entity_map, foreign_key: 'type', inverse_of: 'blocks'
    belongs_to :entity, dependent: :destroy, foreign_key: 'data', inverse_of: 'block'
  end
end
