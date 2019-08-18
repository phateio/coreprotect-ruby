# coreprotect-ruby
An utility for purging old data of CoreProtect in production

**WARNING: This repo is still in development. Use at your own risk.**

## Requirements
* Ruby >= 2.0.0

## Recommendations
* `rbenv --version` # rbenv 1.0.0
* `ruby --version` # ruby 2.5.5p157 (2019-03-15 revision 67260) [x86_64-darwin18]
* `mysql --version` # mysql  Ver 14.14 Distrib 5.7.21, for osx10.11 (x86_64) using  EditLine wrapper

## Installation

1. Install Ruby if you haven't yet:

       $ rbenv install --skip-existing

2. Install bundler if you haven't yet:

       $ gem install bundler

3. Install gems:

       $ bundle install

4. Create your own environment variables configuration:

       $ cp .env.template .env

5. Edit database configurations:

       $ vi .env

## Usage

Use `thor help co:purge` command for help:

```
Usage:
  thor co:purge

Options:
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

       $ thor co:purge

- Delete blocks older than 1546300800 (Tue, 01 Jan 2019 00:00:00 UTC +00:00):

       $ thor co:purge --end=1546300800

- Delete blocks of fire, water and lava spreading:

       $ thor co:purge --user=#fire,#water,#lava

- Delete blocks of a specific world:

       $ thor co:purge --world=world_2018

- Delete blocks without prompt:

       $ thor co:purge --yes

## Contributing
Bug reports and pull requests are welcome.

## License
coreprotect-ruby is released under the [MIT License](http://opensource.org/licenses/MIT).
