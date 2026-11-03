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
  # A (wid, x, z) column with at least this many rows is trimmed whole through the
  # covering (wid, x, z, time) index, instead of per-(x, y, z, action) which must
  # table-look-up every row to filter y/action -- unworkable on a machine column of
  # millions of rows (a single victim batch there exceeds max_statement_time). Only
  # automated machines pile up this much at one column and they dominate it, so
  # collapsing to per-column keep is safe; normal play stays far below and keeps its
  # precise per-(y, action) trim.
  COVERING_THRESHOLD = 50_000
  # Seconds a row's time may run ahead of its rowid order. CoreProtect writes co_block
  # in time order (measured 0 s skew over 1.8M rows), so this is only a safety margin.
  TRIM_TIME_SLACK = 600
  # The hot-coordinate scan reads a segment in chunks this size, so no single GROUP BY
  # holds the disk for a whole 1M-row segment.
  HOT_SCAN_CHUNK = 100_000
  # Seconds between production-health checks while trim is yielding.
  YIELD_POLL_SECONDS = 30
  TRIM_STATE_FILE = File.expand_path('db/trim_state.yml', __dir__)

  desc 'purge', 'Purge blocks from the database'

  method_option :action, type: :string, aliases: '-a', desc: 'Specific actions (separated by commas)'
  method_option :dry_run, type: :boolean, default: false, desc: 'Report the rows without deleting'
  method_option :end, type: :numeric, desc: 'Stop at specific timestamp'
  method_option :start, type: :numeric, desc: 'Started at specific timestamp'
  method_option :step, type: :numeric, default: 1000, desc: 'Iterate with specific number of rows'
  method_option :timeout, type: :numeric, default: 600,
                          desc: 'Session max_statement_time in seconds (overrides TIMEOUT for this run)'
  method_option :user, type: :string, aliases: '-u', desc: 'Specific users (separated by commas)'
  method_option :world, type: :string, aliases: '-w', desc: 'Specific worlds (separated by commas)'

  def purge
    before_action
    start_block.rowid.step(end_block.rowid, limit_param, &purge_proc)
  rescue StandardError, Interrupt => e
    warn e.message
  ensure
    human_count = ActiveSupport::NumberHelper.number_to_human(@purged_row_count)
    message_key = options[:dry_run] ? :would_purge_rows_message : :purged_rows_message
    puts I18n.t(message_key, count: human_count)
    resume_message
  end

  desc 'purge_orphaned_entities', 'Purge orphaned entities from the database'

  method_option :dry_run, type: :boolean, default: false, desc: 'Report the orphaned entities without deleting'
  method_option :end, type: :numeric, desc: 'Stop at specific entity rowid'
  method_option :start, type: :numeric, desc: 'Started at specific entity rowid'
  method_option :step, type: :numeric, default: 1000, desc: 'Iterate with specific number of rows'
  method_option :timeout, type: :numeric, default: 600,
                          desc: 'Session max_statement_time in seconds (overrides TIMEOUT for this run)'

  def purge_orphaned_entities
    before_action_orphaned_entities
    start_entity.rowid.step(end_entity.rowid, orphaned_limit_param, &purge_orphaned_proc)
  rescue StandardError, Interrupt => e
    warn e.message
  ensure
    human_count = ActiveSupport::NumberHelper.number_to_human(@purged_row_count)
    message_key = options[:dry_run] ? :would_purge_orphaned_entities_message : :purged_orphaned_entities_message
    puts I18n.t(message_key, count: human_count)
    resume_orphaned_message
  end

  desc 'trim', 'Trim hot coordinates in co_block down to their newest rows'

  method_option :action, type: :string, aliases: '-a', default: '-block,+block,click',
                         desc: 'Specific actions (separated by commas)'
  method_option :dry_run, type: :boolean, default: false, desc: 'Report hot coordinates without deleting'
  method_option :end, type: :numeric, desc: 'Stop at specific block rowid'
  method_option :keep, type: :numeric, default: 7, desc: 'Newest rows to keep per hot coordinate'
  method_option :start, type: :numeric, desc: 'Started at specific block rowid (overrides the checkpoint)'
  method_option :step, type: :numeric, default: 100, desc: 'Delete with specific number of rows per query'
  method_option :threshold, type: :numeric, default: 100,
                            desc: 'New rows per coordinate within the scan window to flag it as hot'
  method_option :throttle, type: :numeric, default: 9,
                           desc: 'Sleep throttle*(query seconds) after each query; disk duty ~ 1/(1+throttle)'
  method_option :yield_after, type: :numeric, default: 60,
                              desc: 'Pause while another transaction has been open this many seconds ' \
                                    'or a lock wait exists (0 disables)'
  method_option :timeout, type: :numeric, default: 600,
                          desc: 'Session max_statement_time in seconds (overrides TIMEOUT for this run)'

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

  def before_action
    @purged_row_count = 0
    end_block.id > start_block.id || exit
    show_estimate(:estimated_record_deletion_message, end_block.rowid - start_block.rowid)
    apply_session_timeout
    enable_active_record_logger unless options[:dry_run]
  end

  def show_estimate(message_key, count)
    puts I18n.t(message_key, count: number_to_human(count))
  end

  def apply_session_timeout
    ActiveRecord::Base.connection.execute("SET SESSION max_statement_time = #{Integer(options[:timeout])}")
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
      scope = Block.where(block_options).where(rowid: r1..(r1 + limit_param - 1))
      @peek_block = scope.first
      next if @peek_block.nil?

      @last_block = @peek_block
      @purged_row_count += options[:dry_run] ? scope.count : scope.delete_all
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
    end_entity.id > start_entity.id || exit
    show_estimate(:estimated_orphaned_scan_message, end_entity.rowid - start_entity.rowid)
    apply_session_timeout
    enable_active_record_logger unless options[:dry_run]
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
      r2 = r1 + orphaned_limit_param - 1
      orphaned_ids = Entity.orphaned.where(rowid: r1..r2).pluck(:rowid)
      next if orphaned_ids.empty?

      @last_entity = Entity.find_by(rowid: orphaned_ids.last)
      @purged_row_count += options[:dry_run] ? orphaned_ids.size : Entity.where(rowid: orphaned_ids).delete_all
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
    show_estimate(:estimated_trim_scan_message, trim_to - trim_from)
    apply_session_timeout
    enable_active_record_logger unless options[:dry_run]
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
    write_trim_state('rowid' => rowid)
  end

  # Record which of the segment's hot keys are done, so an interrupted run resumes at
  # the next key instead of re-scanning the segment and re-checking every finished one.
  def save_segment_progress(range, keys, done)
    segment = { 'from' => range.first, 'to' => range.last, 'keys' => keys, 'done' => done }
    write_trim_state(trim_state.merge('segment' => segment))
  end

  def write_trim_state(state)
    @trim_state = state
    File.write(TRIM_STATE_FILE, state.to_yaml)
  end

  def saved_segment(range)
    segment = trim_state['segment']
    segment if segment && segment['from'] == range.first && segment['to'] == range.last
  end

  def trim_proc
    proc do |r1|
      r2 = [r1 + TRIM_SEGMENT_SIZE - 1, trim_to].min
      begin_segment(r2)
      trim_segment(r1..r2)
      save_trim_state(r2) unless options[:dry_run]
    end
  end

  def trim_segment(range)
    keys, done = segment_hot_keys(range)
    keys.each_with_index do |key, index|
      next if index < done

      trim_coordinate_isolated(key)
      save_segment_progress(range, keys, index + 1) unless options[:dry_run]
    end
  end

  # One history-heavy coordinate must never abort the whole run and forfeit the
  # segment's checkpoint; skip it and carry on with the rest.
  def trim_coordinate_isolated(key)
    trim_coordinate(key)
  rescue ActiveRecord::StatementInvalid => e
    warn I18n.t(:trim_coordinate_skipped_message, error: e.message, **coordinate_label(key))
  end

  def segment_hot_keys(range)
    if (segment = saved_segment(range))
      puts I18n.t(:trim_segment_resume_message, done: segment['done'], total: segment['keys'].size)
      return [segment['keys'], segment['done']]
    end

    [hot_coordinates(range.first, range.last).keys.sort, 0]
  end

  # Per-segment state: the column memos below are only valid within one segment, since
  # a column's size and trimmed status change as the upper rowid moves on.
  def begin_segment(upper_rowid)
    @upper_rowid = upper_rowid
    @time_ceiling = Block.where(rowid: ..upper_rowid).order(rowid: :desc).pick(:time) + TRIM_TIME_SLACK
    @big_column = {}
    @columns_trimmed = {}
  end

  # Bound a time-ordered scan to the segment. `rowid <=` alone filters only after the
  # (wid, x, z, time) index has walked every newer row (with a table look-up each on the
  # precise path); on an active machine column a lagging run faces hundreds of thousands
  # of them per coordinate, past max_statement_time. The time ceiling starts the index
  # range at the segment instead; TRIM_TIME_SLACK absorbs rows whose time runs ahead
  # of their rowid order.
  def segment_bound(scope)
    scope.where(rowid: ..@upper_rowid, time: ..@time_ceiling)
  end

  # GROUP BY the segment in HOT_SCAN_CHUNK slices and sum the counts. A key reaching the
  # threshold over the whole segment has at least threshold/chunks rows in one chunk, so
  # each slice keeps only keys at that floor; summing kept slices can only undercount, so
  # the result is a subset of the whole-segment answer -- trim may miss a key, never add one.
  def hot_coordinates(rowid_from, rowid_to)
    counts = Hash.new(0)
    rowid_from.step(rowid_to, HOT_SCAN_CHUNK) do |c1|
      chunk = c1..[c1 + HOT_SCAN_CHUNK - 1, rowid_to].min
      paced { hot_chunk_counts(chunk) }.each { |key, count| counts[key] += count }
    end
    counts.select { |_key, count| count >= trim_threshold }
  end

  def hot_chunk_counts(rowids)
    Block.where(rowid: rowids, action: option_action_ids)
         .group(:wid, :x, :y, :z, :action).having('COUNT(*) >= ?', hot_chunk_floor).count
  end

  def hot_chunk_floor
    @hot_chunk_floor ||= (trim_threshold * HOT_SCAN_CHUNK.fdiv(TRIM_SEGMENT_SIZE)).ceil
  end

  # Route each hot coordinate by how big its (wid, x, z) column is. A machine column
  # (a COVERING_THRESHOLD-th newest row exists) is trimmed whole through the covering
  # index; a normal coordinate keeps its precise per-(y, action) trim. Once a big column
  # is trimmed whole, its other (y, action) hot keys in the same segment are skipped.
  def trim_coordinate(key)
    column = key.values_at(0, 1, 3)
    return if column_trimmed?(column)

    if big_column?(column)
      trim_big_column(column)
    else
      trim_small_coordinate(key)
    end
  end

  # Precise path: keep the newest `--keep` rows per (wid, x, y, z, action). The cutoff
  # (the keep-th newest rowid) is found through the (wid, x, z, time) index in time
  # order (O(keep) look-ups, no rowid filesort); rows below it are deleted in bounded
  # `--step` slices, so no single statement scales with the backlog.
  def trim_small_coordinate(key)
    cutoff = paced { coordinate_cutoff(key) }
    return if cutoff.nil?

    return report_planned_trim(key, cutoff) if options[:dry_run]

    trimmed = delete_below(key, cutoff)
    return if trimmed.zero?

    @trimmed_row_count += trimmed
    puts trim_coordinate_message(key, trimmed + trim_keep, trimmed)
  end

  # Covering path for a machine column: keep the newest `--keep` rows of the whole
  # (wid, x, z) column. Both the cutoff and the delete ride the (wid, x, z, time) index
  # with no table look-up, so a million-row column trims at index speed instead of
  # stalling on per-row y/action filtering.
  def trim_big_column(column)
    mark_column_trimmed(column)
    cutoff = paced { column_cutoff(column) }
    return if cutoff.nil?

    return report_planned_column(column, cutoff) if options[:dry_run]

    trimmed = delete_column_below(column, cutoff)
    return if trimmed.zero?

    @trimmed_row_count += trimmed
    puts column_trim_message(column, trimmed + trim_keep, trimmed)
  end

  # Is this (wid, x, z) column a machine column? Test index-only whether a
  # COVERING_THRESHOLD-th newest row exists (O(threshold) leaf reads through the
  # (wid, x, z, time) index) instead of a full COUNT of a million-row column. Memoized
  # per column, since a column carries several (y, action) hot keys in one segment.
  def big_column?(column)
    @big_column.fetch(column) do
      @big_column[column] = paced do
        !segment_bound(column_scope(column)).order(time: :desc).offset(COVERING_THRESHOLD - 1)
                                            .limit(1).pick(:rowid).nil?
      end
    end
  end

  def column_cutoff(column)
    segment_bound(column_scope(column)).order(time: :desc).offset(trim_keep - 1).limit(1).pick(:rowid)
  end

  def delete_column_below(column, cutoff)
    scope = segment_bound(column_scope(column)).where(rowid: ...cutoff)
    delete_in_batches { scope.limit(limit_param).delete_all }
  end

  def column_scope(column)
    wid, x, z = column
    Block.where(wid: wid, x: x, z: z)
  end

  # Delete in --step slices until a batch comes up short, each slice paced.
  # The block runs one slice and returns how many rows it deleted.
  def delete_in_batches(&delete_slice)
    trimmed = 0
    loop do
      deleted = paced(&delete_slice)
      trimmed += deleted
      break if deleted < limit_param
    end
    trimmed
  end

  # Run one unit of trim work politely: wait while production looks busy, then sleep
  # throttle*(its seconds) afterwards, so trim's disk duty settles at ~1/(1+throttle)
  # and it never adds load while CoreProtect's consumer is already backed up.
  def paced
    yield_to_production
    started = monotonic_now
    result = yield
    throttle_after(started)
    result
  end

  def throttle_after(started)
    factor = options[:throttle].to_f
    return if factor <= 0

    sleep(factor * (monotonic_now - started))
  end

  # CoreProtect commits each consumer batch as one transaction, so a transaction that
  # has stayed open long (or any lock wait) means the consumer is backed up. Poll until
  # it clears; a long wait is fine, adding load to a backed-up server is not.
  def yield_to_production
    return if options[:yield_after].to_i <= 0

    announced = false
    while (reason = production_busy)
      puts I18n.t(:trim_yield_message, reason: reason) unless announced
      announced = true
      sleep YIELD_POLL_SECONDS
    end
    puts I18n.t(:trim_resume_message) if announced
  end

  # Bypasses the query cache: the same health query must hit the server every poll.
  def production_busy
    connection = ActiveRecord::Base.connection
    connection.uncached do
      age = connection.select_value(<<~SQL).to_i
        SELECT COALESCE(MAX(TIMESTAMPDIFF(SECOND, trx_started, NOW())), 0)
        FROM information_schema.innodb_trx WHERE trx_mysql_thread_id <> CONNECTION_ID()
      SQL
      next "a transaction open #{age}s" if age >= options[:yield_after].to_i

      waits = connection.select_value('SELECT COUNT(*) FROM information_schema.innodb_lock_waits').to_i
      "#{waits} lock wait(s)" if waits.positive?
    end
  end

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def report_planned_column(column, cutoff)
    victims = paced { segment_bound(column_scope(column)).where(rowid: ...cutoff).count }
    return if victims.zero?

    @trimmed_row_count += victims
    puts column_trim_message(column, victims + trim_keep, victims)
  end

  def column_trimmed?(column)
    @columns_trimmed.key?(column)
  end

  def mark_column_trimmed(column)
    @columns_trimmed[column] = true
  end

  def coordinate_cutoff(key)
    segment_bound(Block.where(coordinate_scope(key))).order(time: :desc).offset(trim_keep - 1).limit(1).pick(:rowid)
  end

  # Precise delete below the cutoff, page by page. `y`/`action` aren't in the
  # (wid, x, z, time) index, so every row is filtered on a table look-up; the keyset
  # cursor (see keyset_page) keeps that to once per row instead of re-scanning the whole
  # column every batch (O(n^2) on a million-row column, which stalled the run for days).
  def delete_below(key, cutoff)
    scope = segment_bound(Block.where(coordinate_scope(key))).where(rowid: ...cutoff)
    cursor = nil
    delete_in_batches do
      batch = keyset_page(scope, cursor)
      cursor = batch.last unless batch.empty?
      Block.where(rowid: batch.map { |row| row[1] }).delete_all
    end
  end

  # One (time, rowid) keyset page below the cutoff, resuming after the cursor. Ordering
  # by (time, rowid) matches the (wid, x, z, time) index, so there's no filesort, and
  # the cursor stops each batch from re-scanning the column's history.
  def keyset_page(scope, cursor)
    scope = scope.where('time > :t OR (time = :t AND rowid > :r)', t: cursor[0], r: cursor[1]) if cursor
    scope.order(:time, :rowid).limit(limit_param).pluck(:time, :rowid)
  end

  # A dry run deletes nothing, so a coordinate that stays hot across segments is
  # re-counted each time (its cutoff climbs as the segment's upper rowid grows);
  # report only the victims not already reported for it, so the dry-run total
  # matches what a real (deleting) run would remove.
  def report_planned_trim(key, cutoff)
    cumulative_victims = victim_count(key, cutoff)
    victims = cumulative_victims - planned_victims[key]
    planned_victims[key] = cumulative_victims
    return if victims.zero?

    @trimmed_row_count += victims
    puts trim_coordinate_message(key, cumulative_victims + trim_keep, victims)
  end

  def victim_count(key, cutoff)
    paced { segment_bound(Block.where(coordinate_scope(key))).where(rowid: ...cutoff).count }
  end

  def planned_victims
    @planned_victims ||= Hash.new(0)
  end

  def coordinate_scope(key)
    wid, x, y, z, action = key
    { wid: wid, x: x, y: y, z: z, action: action }
  end

  def coordinate_label(key)
    wid, x, y, z, action = key
    { world: world_name(wid), x: x, y: y, z: z, action: ACTIONS.key(action) }
  end

  def trim_coordinate_message(key, total, victim_count)
    message_key = options[:dry_run] ? :trim_dry_run_coordinate_message : :trim_coordinate_message
    I18n.t(message_key, count: victim_count, total: total, keep: trim_keep, **coordinate_label(key))
  end

  def column_trim_message(column, total, victim_count)
    wid, x, z = column
    message_key = options[:dry_run] ? :trim_dry_run_column_message : :trim_column_message
    I18n.t(message_key, count: victim_count, total: total, keep: trim_keep,
                        world: world_name(wid), x: x, z: z)
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
