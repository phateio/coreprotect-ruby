# frozen_string_literal: true

class MySimpleFormatter < ActiveSupport::Logger::SimpleFormatter
  def call(_severity, timestamp, _progname, message)
    format(I18n.t(:logger_format), timestamp: timestamp.strftime('%F %T'), message: message)
  end
end

class Co < Thor
  include ActiveSupport::NumberHelper

  desc 'purge', 'Purge blocks from the database'

  method_option :end, type: :numeric, desc: 'Stop at specific timestamp'
  method_option :start, type: :numeric, desc: 'Started at specific timestamp'
  method_option :step, type: :numeric, default: 1000, desc: 'Iterate with specific number of rows'
  method_option :user, type: :string, aliases: '-u', desc: 'Specific users (separated by commas)'
  method_option :world, type: :string, aliases: '-w', desc: 'Specific worlds (separated by commas)'
  method_option :yes, type: :boolean, aliases: '-y', default: false, desc: 'Delete the records without prompt'

  def purge
    before_action
    start_block.rowid.step(end_block.rowid, limit_param, &purge_proc)
  rescue StandardError, Interrupt => e
    STDERR.puts e.message
  ensure
    human_count = ActiveSupport::NumberHelper.number_to_human(@purged_row_count)
    puts I18n.t(:purged_rows_message, count: human_count)
    resume_message
  end

  private

  def continue?
    if yes?
      show_statistics(@estimated_row_count)
    else
      answer = prompt_question(@estimated_row_count)

      unless answer.casecmp('Y').zero?
        puts I18n.t(:prompt_canceled_message)
        return false
      end
    end
    true
  end

  def yes?
    options[:yes]
  end

  def before_action
    @purged_row_count = 0
    @estimated_row_count = number_to_human(end_block.rowid - start_block.rowid)

    end_block.id > start_block.id || exit
    continue? || exit
    enable_active_record_logger
  end

  def start_block
    return @start_block if @start_block
    return @last_block = @start_block = Block.first if options[:start].nil?

    @last_block = @start_block = Block.bsearch { |block| block.time >= Integer(options[:start]) }
  end

  def end_block
    return @end_block if @end_block

    @end_block = if options[:end]
                   Block.bsearch { |block| block.time >= Integer(options[:end]) }
                 else
                   Block.bsearch { |block| block.time >= Integer(30.days.ago) }
                 end
  end

  def purge_proc
    proc do |r1|
      r2 = r1 + limit_param
      @peek_block = Block.where(block_options).where(rowid: r1..r2).first
      next if @peek_block.nil?

      @last_block = @peek_block
      @purged_row_count += Block.where(block_options).where(rowid: r1..r2).delete_all
    end
  end

  def limit_param
    options[:step]
  end

  def option_user_ids
    users = options[:user].split(',')
    users.each { |user| User.find_by!(user: user) }
    User.where(user: options[:user].split(',')).ids
  end

  def block_options
    return @block_options if @block_options

    @block_options = {}
    @block_options[:wid] = World.find_by!(world: options[:world].split(',')) if options[:world]
    @block_options[:user] = option_user_ids if options[:user]
    @block_options
  end

  def show_statistics(human_count)
    puts I18n.t(:estimated_record_deletion_message, count: human_count)
  end

  def prompt_question(human_count)
    print format('%<message>s [y/N] ', message: I18n.t(:record_deletion_prompt, count: human_count))
    STDIN.getc
  end

  def enable_active_record_logger
    logger = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = MySimpleFormatter.new
    ActiveRecord::Base.logger = logger
  end

  def resume_message
    return if @last_block.nil?

    params = {
      timestamp: @last_block.time,
      human_time: Time.at(@last_block.time)
    }
    puts I18n.t(:resume_notice_message, params)
  end
end
