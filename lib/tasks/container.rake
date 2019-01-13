# frozen_string_literal: true

namespace :container do
  desc 'Purge containers from the database'
  task :purge do
    EXPIRED_TIME = Integer(1.month.ago)
    container_id = Container.bsearch { |container| container.time > EXPIRED_TIME }.rowid

    puts format('Estimated %d rows to be deleted', container_id - Container.first.rowid)
    if ActiveRecord::Type::Boolean.new.cast(ENV['DELETE'])
      legacy_containers = Container.arel_table[:rowid].lt(container_id)
      Container.where(legacy_containers).find_in_batches do |containers|
        Container.where(rowid: containers.map(&:id)).delete_all
      end
    end
  end
end
