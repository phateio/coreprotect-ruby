# frozen_string_literal: true

# co_session
class Session < ApplicationRecord
  self.table_name = 'co_session'

  belongs_to :user, foreign_key: 'user', inverse_of: 'sessions'
end
