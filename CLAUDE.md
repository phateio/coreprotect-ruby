# coreprotect-ruby

> **Editing this file:** Consider the whole document before changing it — the right section, the right wording, the most essential form for every sentence. **Length limit: 200 lines** — trim or consolidate before adding.

Ruby utility for purging old **CoreProtect** (Minecraft logging plugin) data from a
production MariaDB database. Still in development — purge operations are destructive,
so validate filters and timestamps carefully.

## Architecture

A thin ActiveRecord layer over the live CoreProtect database, driven by a Thor CLI and
Rake tasks. No web app; the schema is owned by CoreProtect itself, not by migrations here.

**Flow:** `bin/thor` / `bin/rake` → bootstrap (`dotenv` → `config/database.yml` → an
ActiveRecord connection over `mysql2`) → models (`co_*` tables) → MariaDB. Prompts and
log lines are i18n strings from `config/locales/en.yml`.

**Entry points**
- `co.thor` — `Co < Thor`; defines the `co:purge`, `co:purge_orphaned_entities`, and `co:trim`
  commands. Self-bootstrapping: loads env, DB connection, models, and locales at require time.
- `Thorfile` — bootstrap for `bin/thor` (`dotenv`, AR connect, model autoload path, i18n).
- `Rakefile` — bootstrap for `bin/rake`; loads models and `Rake.add_rakelib 'lib/tasks'`.
- `scripts/purge.rb` — standalone `ruby scripts/purge.rb`; ad-hoc bulk delete driven by
  `ENV['START']` (flow blocks + staled enderman/creeper tiles). Not wired into Thor/Rake.
- `bin/` — Bundler binstubs (`thor`, `rake`, `pry`, `rubocop`, …).

**Models** (`models/*.rb`) — all inherit the abstract `ApplicationRecord` and map a
`co_*` table via `self.table_name`; the primary key is `rowid`. The `uzer` association
is a deliberate alias for the `user` foreign-key column (avoids clashing with the column name).
- `Block` (`co_block`) — scopes `removed/placed/clicked/killed/built/flows`; memoized
  special users `fire/water/lava`; `self.bsearch` binary-searches records by `rowid`/`time`.
  Nested `Block::Tile` (default scope `killed`) links to `EntityMap` (via `type`) and
  `Entity` (via `data`, `dependent: :destroy`); scope `staled` = end-world endermen + creepers.
- `Entity` (`co_entity`) — `has_one` `Block::Tile`; scope `orphaned` (NOT EXISTS: no
  killed block references the entity). `EntityMap` (`co_entity_map`) — mob-name lookup.
- `Container` (`co_container`), `Item` (`co_item`, scopes `dropped/picked`) — same shape as `Block`.
- `User` (`co_user`, `has_many` sessions/blocks/containers) and `World` (`co_world`,
  `has_many` blocks/containers) — lookup tables. `Session` (`co_session`) — `belongs_to` user only.

**Rake tasks** (`lib/tasks/*.rake`)
- `db:schema` — dumps `db/schema.rb` from the live DB (see below); also `db:create/migrate/drop/reset`.
- `block:purge` / `container:purge` / `entity:purge` — older ENV-gated purges
  (`FORCE`/`DELETE`), batched `delete_all` of rows older than one month. Superseded by `co:purge`.
- `irb` — pry/irb console with the models loaded.

**Config**
- `config/database.yml` — `mysql2`; every value from `COREPROTECT_DATABASE_*` env;
  `init_command` sets `max_statement_time` from `TIMEOUT` (seconds on MariaDB, not MySQL's milliseconds).
- `.env` (copied from `.env.template`, loaded by `dotenv`) — DB host/name/user/password, `TIMEOUT`.
- Gems: Ruby ≥ 3.1, `activerecord`/`activesupport ~> 7.2`, `mysql2`, `thor`, `i18n`, `dotenv`, `pry`.

## Commands

### `co:purge` — purge old block records

```bash
bin/thor co:purge [options]
```

Options:
- `--start=TIMESTAMP` — start from a specific Unix timestamp
- `--end=TIMESTAMP` — stop at a specific Unix timestamp (default: 30 days ago)
- `--world=WORLDS` / `-w` — specific worlds (comma-separated)
- `--user=USERS` / `-u` — specific users (comma-separated)
- `--action=ACTION` / `-a` — filter by action (`-block`, `+block`, `click`, `kill`)
- `--step=N` — batch size (default: 1000)
- `--yes` / `-y` — skip confirmation prompt

```bash
bin/thor co:purge --world=world_2024,world_2024_nether --start=1718565253
```

### `co:purge_orphaned_entities` — clean up orphaned entities

After `co:purge`, entities in `co_entity` may become orphaned (because `delete_all`
bypasses `dependent: :destroy`). This command removes entities that no killed block
still references, using batched deletion.

```bash
bin/thor co:purge_orphaned_entities [options]
```

Options:
- `--start=ROWID` — start from a specific entity rowid
- `--end=ROWID` — stop at a specific entity rowid
- `--step=N` — batch size (default: 1000)
- `--yes` / `-y` — skip confirmation prompt

```bash
# 1. Purge old blocks
bin/thor co:purge --world=world_2024 --start=1718565253
# 2. Clean up orphaned entities
bin/thor co:purge_orphaned_entities -y
```

### `co:trim` — trim hot coordinates in `co_block`

Incremental "hot coordinate" trim. Automated machines (auto tree farms, gravity/TNT
machines) write thousands of rows at fixed coordinates; on tree growth CoreProtect's
`whoPlaced()` SELECT (forced `USE INDEX(wid)`; the index lacks `y`) must scan the whole
accumulated column, stalling CoreProtect's single-threaded consumer. `co:trim` keeps the
invariant "any coordinate gaining ≥ threshold new rows in a scan window is trimmed to its
newest N rows per `(wid, x, y, z, action)`"; quiet coordinates (old buildings) are never
touched. Complements `co:purge` — purge deletes by age, trim caps per-coordinate
accumulation while preserving old history.

Scans rows added since the last checkpoint (primary-key range scan) in 1,000,000-rowid
segments: per segment, `GROUP BY (wid, x, y, z, action) HAVING COUNT(*) >= threshold`
finds hot keys; each hot key keeps its newest `--keep` rows (bounded by the segment's
upper rowid) and the rest are deleted by primary key in `--step`-sized slices. After each
segment the checkpoint is saved to `db/trim_state.yml` (gitignored), so interrupted runs
resume automatically.

```bash
bin/thor co:trim [options]
```

Options:
- `--start=ROWID` — scan from this rowid (overrides the checkpoint; required on the very
  first run, when no checkpoint file exists)
- `--end=ROWID` — stop at this rowid (default: current max)
- `--keep=N` — newest rows to keep per hot coordinate (default: 7)
- `--threshold=N` — new rows per coordinate within the window to flag it as hot
  (default: 100; must be ≥ `--keep`)
- `--action=LIST` / `-a` — actions to consider (default: `-block,+block,click`; `kill` is
  excluded by default because deleting kill rows orphans `co_entity` rows — if you include
  it, run `co:purge_orphaned_entities` afterwards; the command prints a reminder)
- `--step=N` — delete batch size (default: 1000)
- `--timeout=N` — session `max_statement_time` in seconds for this run (default: 600;
  overrides the `.env` `TIMEOUT` of 10 s, which would kill the long scans/plucks on
  history-heavy coordinates)
- `--dry-run` — report hot coordinates and planned deletions without deleting and without
  saving the checkpoint
- `--yes` / `-y` — skip confirmation prompt

```bash
# Typical cron usage: daily incremental trim from the last checkpoint
bin/thor co:trim -y
```

## Database Schema (`db/schema.rb`)

`db/schema.rb` is an auto-generated mirror of the live CoreProtect database. It is
the authoritative schema reference for the models — **do not hand-edit it**. The
target database is **CoreProtect v24.0** on MariaDB 10.11.x.

- **CoreProtect applies its own `ALTER TABLE` patches on startup** (see its
  `patch/script/__X_Y_Z` classes, where `X.Y.Z` is the release version). These run
  as native, blocking `ALGORITHM=COPY` alters. ⚠ On the huge tables (`co_container`
  ~60GB, `co_item`, `co_block`) a column type change locks the table for the entire
  copy and **hangs the server** — do NOT just let CoreProtect run it.

  - **Before upgrading**, pre-run the type change with `pt-online-schema-change`
    (online, no downtime). Each patch guards its alter with a type check
    (`modifyColumn` → `hasColumnType`), so when CoreProtect starts and finds the
    column already matches, it **skips** the blocking alter. See `/root/CLAUDE.md`
    (pt-osc procedure) and `/root/docs/mysql-ssd-migration.md`. For v24.0, run these
    via pt-osc first, *then* upgrade:

        ALTER TABLE co_container MODIFY metadata MEDIUMBLOB
        ALTER TABLE co_item      MODIFY data     MEDIUMBLOB

    Small tables (e.g. the v24.0 `co_sign` → `utf8mb4` conversion) are fine to let
    CoreProtect alter automatically.

  - **After upgrading**, re-sync the schema and commit the diff (keeps `db/schema.rb`
    in sync with the database — the one project-specific review gate):

        bundle exec rake db:schema   # dumps the live DB via ActiveRecord::SchemaDumper

- **Host-side customizations** — these are NOT created by CoreProtect; they were
  added manually on this host for purge performance. Do not "correct" them away:
  - `co_block.rowid` is `bigint unsigned` (CoreProtect ships signed `bigint`).
  - `co_block` has extra indexes `data (data, time)` and
    `user_action (user, action, time)`.

- **Known caveat**: `bundle exec` may fail on this host when `Gemfile.lock` pins
  gems that are not installed locally (e.g. a yanked `connection_pool 3.0.2`, or
  `activerecord 7.2.3.1` vs the installed 7.2.3). If so, run `bundle update` first,
  or dump using the system gems directly (mirrors the `db:schema` task):

      ruby -e 'require "dotenv/load"; require "erb"; require "yaml"; require "active_record"; require "active_record/schema_dumper"; \
        cfg = YAML.load(ERB.new(File.read("config/database.yml")).result); \
        ActiveRecord::Base.establish_connection(cfg); \
        File.open("db/schema.rb", "w:utf-8") { |f| ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, f) }'

## Resources

- **README.md** — usage and examples.
- **CoreProtect** (schema source): https://github.com/PlayPro/CoreProtect (schema patches
  live in `src/main/java/net/coreprotect/patch/script/`).
