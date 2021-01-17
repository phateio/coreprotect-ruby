# frozen_string_literal: true

# co_item
class Item < ApplicationRecord
  self.table_name = 'co_item'
  self.inheritance_column = nil

  attribute :action, ActiveModel::Type::Integer.new

  belongs_to :world, foreign_key: 'wid', inverse_of: 'items'
  belongs_to :uzer, class_name: 'user', foreign_key: 'user', inverse_of: 'items'

  scope :dropped, -> { where(action: 2) }
  scope :picked, -> { where(action: 3) }
end
