# coreprotect-ruby
An utility for purging old data of CoreProtect in production

**WARNING: This repo is still in development. Use at your own risk.**

## Requirements
* Ruby >= 3.1.0 (tested with Ruby 3.1.2 on Debian 12)

## Recommendations
* `rbenv --version` # rbenv 1.3.0+
* `ruby --version` # ruby 3.1.2p20 (2022-04-12 revision 4491bb740a) [x86_64-linux-gnu]
* `mysql --version` # mysql Ver 15.1 Distrib 10.11.14-MariaDB, for debian-linux-gnu (x86_64) using EditLine wrapper

## Installation

1. Install Ruby if you haven't yet:

       $ rbenv install --skip-existing

2. Install bundler if you haven't yet:

       $ gem install bundler

3. Install gems:

       $ bundle install --path vendor/bundle --binstubs bin

4. Create your own environment variables configuration:

       $ cp .env.template .env

5. Edit database configurations:

       $ vi .env

## Usage

Use `bin/thor help co:purge` command for help:

```
Usage:
  thor co:purge

Options:
  -a, [--action=ACTION]    # Specific actions (separated by commas)
      [--end=N]            # Stop at specific timestamp
      [--start=N]          # Started at specific timestamp
      [--step=N]           # Iterate with specific number of rows
                           # Default: 1000
  -u, [--user=USER]        # Specific users (separated by commas)
  -w, [--world=WORLD]      # Specific worlds (separated by commas)
  -y, [--yes], [--no-yes]  # Delete the records without prompt

Purge blocks from the database
```

## Examples

- Delete blocks older than 30 days ago (default):

       $ bin/thor co:purge

- Delete blocks older than 1546300800 (Tue, 01 Jan 2019 00:00:00 UTC +00:00):

       $ bin/thor co:purge --end=1546300800

- Delete blocks of fire, water and lava spreading:

       $ bin/thor co:purge --user=#fire,#water,#lava --action=+block

- Delete blocks of a specific world:

       $ bin/thor co:purge --world=world_2018

- Delete blocks without prompt:

       $ bin/thor co:purge --yes

## Contributing
Bug reports and pull requests are welcome.

## License
coreprotect-ruby is released under the [MIT License](http://opensource.org/licenses/MIT).
