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
  scope :built, -> { where(action: [0, 1]) }
  scope :flows, -> { where(arel_table[:user].in([fire, water, lava])) }

  def self.fire
    @fire ||= User.find_by!(user: '#fire')
  end

  def self.water
    @water ||= User.find_by!(user: '#water')
  end

  def self.lava
    @lava ||= User.find_by!(user: '#lava')
  end

  class Tile < Block
    default_scope { killed }

    belongs_to :entity_map, foreign_key: 'type', inverse_of: 'blocks'
    belongs_to :entity, dependent: :destroy, foreign_key: 'data', inverse_of: 'block'

    scope :staled, -> { where(endermans_2014.or(endermans_2017).or(creepers)) }

    def self.endermans_2014
      @endermans2014 ||= begin
        world_2014_the_end = World.find_by!(world: 'world_2014_the_end')
        entity_enderman = EntityMap.find_by!(entity: 'enderman')

        arel_table[:wid].eq(world_2014_the_end.id).and(
          arel_table[:type].eq(entity_enderman.id)
        )
      end
    end

    def self.endermans_2017
      @endermans2017 ||= begin
        world_2017_the_end = World.find_by!(world: 'world_2014_the_end')
        entity_enderman = EntityMap.find_by!(entity: 'enderman')

        arel_table[:wid].eq(world_2017_the_end.id).and(
          arel_table[:type].eq(entity_enderman.id)
        )
      end
    end

    def self.creepers
      @creepers ||= begin
        creeper = User.find_by!(user: '#creeper')
        entity_creeper = EntityMap.find_by!(entity: 'creeper')

        arel_table[:user].eq(creeper.rowid).and(
          arel_table[:type].eq(entity_creeper.id)
        )
      end
    end
  end

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
