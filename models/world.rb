# frozen_string_literal: true

# co_world
class World < ApplicationRecord
  self.table_name = 'co_world'

  has_many :blocks, dependent: :destroy, foreign_key: 'wid', inverse_of: 'world'
  has_many :containers, dependent: :destroy, foreign_key: 'wid', inverse_of: 'world'
end
