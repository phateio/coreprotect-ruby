# frozen_string_literal: true

namespace :block do
  desc 'Purge blocks from the database'
  task :purge do
    EXPIRED_TIME = Integer(1.month.ago)
    block_id = Block.bsearch { |block| block.time > EXPIRED_TIME }.rowid
    count = block_id - Block.first.rowid
    human_count = ActiveSupport::NumberHelper.number_to_human(count)

    if force_delete?
      show_statistics(human_count)
    else
      answer = prompt_question(human_count)

      unless answer.casecmp('Y').zero?
        puts I18n.t('prompt_canceled_message')
        exit
      end
    end

    legacy_blocks = Block.arel_table[:rowid].lt(block_id)
    Block.where(legacy_blocks).find_in_batches do |blocks|
      Block.where(rowid: blocks.map(&:id)).delete_all
    end
  end

  def force_delete?
    ActiveRecord::Type::Boolean.new.cast(ENV['FORCE'])
  end

  def show_statistics(human_count)
    puts I18n.t(:estimated_record_deletion_message, count: human_count)
  end

  def prompt_question(human_count)
    print format('%<message>s [y/N] ', message: I18n.t(:record_deletion_prompt, count: human_count))
    STDIN.getc
  end
end
