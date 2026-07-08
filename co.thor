# frozen_string_literal: true

require 'dotenv/load'
require 'active_support'
require 'active_support/core_ext'
require 'erb'
require 'yaml'
require 'active_record'

$stdout.sync = true
$stderr.sync = true

config = YAML.load(ERB.new(File.read(File.expand_path('config/database.yml', __dir__))).result)
ActiveRecord::Base.establish_connection(config)
ActiveRecord::Base.connection.enable_query_cache!

# Load models explicitly (ActiveSupport 7.x removed classic autoloader)
require File.expand_path('models/application_record', __dir__)
Dir[File.expand_path('models/*.rb', __dir__)].each { |file| require file }

I18n.load_path << Dir["#{File.expand_path('config/locales', __dir__)}/*.yml"]

class MySimpleFormatter < ActiveSupport::Logger::SimpleFormatter
  def call(_severity, timestamp, _progname, message)
    format(I18n.t(:logger_format), timestamp: timestamp.strftime('%F %T'), message: message)
  end
end

class Co < Thor
  include ActiveSupport::NumberHelper

  ACTIONS = { '-block' => 0, '+block' => 1, 'click' => 2, 'kill' => 3 }.freeze
  TRIM_SEGMENT_SIZE = 1_000_000
  TRIM_STATE_FILE = File.expand_path('db/trim_state.yml', __dir__)

  desc 'purge', 'Purge blocks from the database'

  method_option :action, type: :string, aliases: '-a', desc: 'Specific actions (separated by commas)'
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
    warn e.message
  ensure
    human_count = ActiveSupport::NumberHelper.number_to_human(@purged_row_count)
    puts I18n.t(:purged_rows_message, count: human_count)
    resume_message
  end

  desc 'purge_orphaned_entities', 'Purge orphaned entities from the database'

  method_option :start, type: :numeric, desc: 'Started at specific entity rowid'
  method_option :end, type: :numeric, desc: 'Stop at specific entity rowid'
  method_option :step, type: :numeric, default: 1000, desc: 'Iterate with specific number of rows'
  method_option :yes, type: :boolean, aliases: '-y', default: false, desc: 'Delete the records without prompt'

  def purge_orphaned_entities
    before_action_orphaned_entities
    start_entity.rowid.step(end_entity.rowid, orphaned_limit_param, &purge_orphaned_proc)
  rescue StandardError, Interrupt => e
    warn e.message
  ensure
    human_count = ActiveSupport::NumberHelper.number_to_human(@purged_row_count)
    puts I18n.t(:purged_orphaned_entities_message, count: human_count)
    resume_orphaned_message
  end

  desc 'trim', 'Trim hot coordinates in co_block down to their newest rows'

  method_option :action, type: :string, aliases: '-a', default: '-block,+block,click',
                         desc: 'Specific actions (separated by commas)'
  method_option :dry_run, type: :boolean, default: false, desc: 'Report hot coordinates without deleting'
  method_option :end, type: :numeric, desc: 'Stop at specific block rowid'
  method_option :keep, type: :numeric, default: 7, desc: 'Newest rows to keep per hot coordinate'
  method_option :start, type: :numeric, desc: 'Started at specific block rowid (overrides the checkpoint)'
  method_option :step, type: :numeric, default: 1000, desc: 'Delete with specific number of rows per query'
  method_option :threshold, type: :numeric, default: 100,
                            desc: 'New rows per coordinate within the scan window to flag it as hot'
  method_option :timeout, type: :numeric, default: 600,
                          desc: 'Session max_statement_time in seconds (overrides TIMEOUT for this run)'
  method_option :yes, type: :boolean, aliases: '-y', default: false, desc: 'Trim the records without prompt'

  def trim
    before_action_trim
    trim_from.step(trim_to, TRIM_SEGMENT_SIZE, &trim_proc)
  rescue StandardError, Interrupt => e
    warn e.message
  ensure
    human_count = ActiveSupport::NumberHelper.number_to_human(@trimmed_row_count)
    message_key = options[:dry_run] ? :would_trim_rows_message : :trimmed_rows_message
    puts I18n.t(message_key, count: human_count)
    trim_notice_messages
  end

  private

  def continue?
    confirm?(@estimated_row_count, :estimated_record_deletion_message, :record_deletion_prompt)
  end

  def confirm?(count, statistics_key, prompt_key)
    if yes?
      puts I18n.t(statistics_key, count: count)
      return true
    end

    print format('%<message>s [y/N] ', message: I18n.t(prompt_key, count: count))
    return true if $stdin.getc.casecmp('Y').zero?

    puts I18n.t(:prompt_canceled_message)
    false
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

  def option_world_ids
    worlds = options[:world].split(',')
    worlds.each { |world| World.find_by!(world: world) }
    World.where(world: worlds).ids
  end

  def option_user_ids
    users = options[:user].split(',')
    users.each { |user| User.find_by!(user: user) }
    User.where(user: users).ids
  end

  def option_action_ids
    options[:action].split(',').map do |action|
      ACTIONS.fetch(action) do
        raise StandardError, "Expected '--action' to be one of #{ACTIONS.keys.join(', ')}"
      end
    end
  end

  def block_options
    return @block_options if @block_options

    @block_options = {}
    @block_options[:wid] = option_world_ids if options[:world]
    @block_options[:user] = option_user_ids if options[:user]
    @block_options[:action] = option_action_ids if options[:action]
    @block_options
  end

  def enable_active_record_logger
    logger = ActiveSupport::Logger.new($stdout)
    logger.formatter = MySimpleFormatter.new
    ActiveRecord::Base.logger = logger
  end

  def resume_message
    return if @last_block.nil?

    params = {
      timestamp: @last_block.time,
      human_time: Time.at(@last_block.time)
    }
    puts I18n.t(:resume_notice_message, **params)
  end

  # Methods for purge_orphaned_entities command

  def before_action_orphaned_entities
    @purged_row_count = 0
    @estimated_row_count = number_to_human(end_entity.rowid - start_entity.rowid)

    end_entity.id > start_entity.id || exit
    continue_orphaned? || exit
    enable_active_record_logger
  end

  def continue_orphaned?
    confirm?(@estimated_row_count, :estimated_orphaned_scan_message, :orphaned_deletion_prompt)
  end

  def start_entity
    return @start_entity if @start_entity
    return @last_entity = @start_entity = Entity.first if options[:start].nil?

    @last_entity = @start_entity = Entity.find_by!(rowid: Integer(options[:start]))
  end

  def end_entity
    return @end_entity if @end_entity

    @end_entity = if options[:end]
                    Entity.find_by!(rowid: Integer(options[:end]))
                  else
                    Entity.last
                  end
  end

  def purge_orphaned_proc
    proc do |r1|
      r2 = r1 + orphaned_limit_param
      orphaned_ids = Entity.orphaned.where(rowid: r1..r2).pluck(:rowid)
      next if orphaned_ids.empty?

      @last_entity = Entity.find_by(rowid: orphaned_ids.last)
      @purged_row_count += Entity.where(rowid: orphaned_ids).delete_all
    end
  end

  def orphaned_limit_param
    options[:step]
  end

  def resume_orphaned_message
    return if @last_entity.nil?

    puts I18n.t(:resume_orphaned_notice_message, rowid: @last_entity.rowid)
  end

  # Methods for trim command

  def before_action_trim
    @trimmed_row_count = 0
    validate_trim_options
    trim_nothing_to_scan if trim_to < trim_from
    @estimated_row_count = number_to_human(trim_to - trim_from)
    continue_trim? || exit
    apply_trim_timeout
    enable_active_record_logger unless options[:dry_run]
  end

  def apply_trim_timeout
    ActiveRecord::Base.connection.execute("SET SESSION max_statement_time = #{Integer(options[:timeout])}")
  end

  def validate_trim_options
    raise StandardError, "Expected '--keep' to be at least 1" if trim_keep < 1
    raise StandardError, "Expected '--threshold' to be at least '--keep'" if trim_threshold < trim_keep

    option_action_ids
  end

  def trim_nothing_to_scan
    puts I18n.t(:trim_nothing_message)
    exit
  end

  def trim_keep
    @trim_keep ||= Integer(options[:keep])
  end

  def trim_threshold
    @trim_threshold ||= Integer(options[:threshold])
  end

  def trim_from
    @trim_from ||= options[:start] ? Integer(options[:start]) : checkpoint_rowid + 1
  end

  def trim_to
    @trim_to ||= options[:end] ? Integer(options[:end]) : Block.last.rowid
  end

  def checkpoint_rowid
    trim_state.fetch('rowid') { raise StandardError, I18n.t(:trim_state_missing_message) }
  end

  def trim_state
    @trim_state ||= File.exist?(TRIM_STATE_FILE) ? YAML.safe_load_file(TRIM_STATE_FILE) : {}
  end

  def checkpoint_floor
    @checkpoint_floor ||= trim_state.fetch('rowid', 0)
  end

  def save_trim_state(rowid)
    return if rowid <= checkpoint_floor

    @last_checkpoint = rowid
    File.write(TRIM_STATE_FILE, { 'rowid' => rowid }.to_yaml)
  end

  def continue_trim?
    if options[:dry_run]
      puts I18n.t(:estimated_trim_scan_message, count: @estimated_row_count)
      return true
    end

    confirm?(@estimated_row_count, :estimated_trim_scan_message, :trim_scan_prompt)
  end

  def trim_proc
    proc do |r1|
      r2 = [r1 + TRIM_SEGMENT_SIZE - 1, trim_to].min
      hot_coordinates(r1, r2).each_key { |key| trim_coordinate(key, r2) }
      save_trim_state(r2) unless options[:dry_run]
    end
  end

  def hot_coordinates(rowid_from, rowid_to)
    Block.where(rowid: rowid_from..rowid_to, action: option_action_ids)
         .group(:wid, :x, :y, :z, :action)
         .having('COUNT(*) >= ?', trim_threshold)
         .count
  end

  def trim_coordinate(key, upper_rowid)
    rowids = coordinate_rowids(key, upper_rowid)
    victim_ids = rowids.drop(trim_keep)
    return if victim_ids.empty?

    return report_planned_trim(key, rowids.size, victim_ids.size) if options[:dry_run]

    puts trim_coordinate_message(key, rowids.size, victim_ids.size)
    trim_victims(victim_ids)
  end

  def coordinate_rowids(key, upper_rowid)
    wid, x, y, z, action = key
    Block.where(wid: wid, x: x, y: y, z: z, action: action)
         .where(rowid: ..upper_rowid).order(rowid: :desc).pluck(:rowid)
  end

  # A dry run deletes nothing, so a coordinate that stays hot across segments is
  # re-plucked in full each time; count only the victims not already reported for
  # it, so the dry-run total matches what a real (deleting) run would remove.
  def report_planned_trim(key, total, cumulative_victims)
    victim_count = cumulative_victims - planned_victims[key]
    planned_victims[key] = cumulative_victims
    return if victim_count.zero?

    puts trim_coordinate_message(key, total, victim_count)
    @trimmed_row_count += victim_count
  end

  def planned_victims
    @planned_victims ||= Hash.new(0)
  end

  def trim_coordinate_message(key, total, victim_count)
    wid, x, y, z, action = key
    message_key = options[:dry_run] ? :trim_dry_run_coordinate_message : :trim_coordinate_message
    I18n.t(message_key, count: victim_count, total: total, world: world_name(wid),
                        x: x, y: y, z: z, action: ACTIONS.key(action), keep: trim_keep)
  end

  def trim_victims(victim_ids)
    victim_ids.each_slice(limit_param) do |ids|
      @trimmed_row_count += Block.where(rowid: ids).delete_all
    end
  end

  def world_name(wid)
    @world_names ||= {}
    @world_names[wid] ||= World.find_by(id: wid)&.world || "wid=#{wid}"
  end

  def trim_notice_messages
    puts I18n.t(:trim_checkpoint_message, rowid: @last_checkpoint) if @last_checkpoint
    puts I18n.t(:trim_kill_notice_message) if @trimmed_row_count.positive? && option_action_ids.include?(3)
  end
end
