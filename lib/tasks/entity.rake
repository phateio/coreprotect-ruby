# frozen_string_literal: true

namespace :entity do
  desc 'Purge entities from the database'
  task :purge do
    EXPIRED_TIME = Integer(1.month.ago)
    entity_id = Entity.bsearch { |entity| entity.time > EXPIRED_TIME }.rowid

    puts format('Estimated %d rows to be deleted', entity_id - Entity.first.rowid)
    if ActiveRecord::Type::Boolean.new.cast(ENV['DELETE'])
      legacy_entities = Entity.arel_table[:rowid].lt(entity_id)
      Entity.where(legacy_entities).find_in_batches do |entities|
        Entity.where(rowid: entities.map(&:id)).delete_all
      end
    end
  end
end
