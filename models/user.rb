# frozen_string_literal: true

# co_user
class User < ApplicationRecord
  self.table_name = 'co_user'

  has_many :sessions, dependent: :destroy, foreign_key: 'user', inverse_of: 'user'
  has_many :blocks, dependent: :destroy, foreign_key: 'user', inverse_of: 'user'
end
