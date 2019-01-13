# coreprotect-ruby
An utility for purging old data of CoreProtect in production

**WARNING: This repo is still in development. Use at your own risk.**

## Requirements
* `rbenv --version` # rbenv 1.0.0
* `ruby --version` # ruby 2.3.3p222 (2016-11-21 revision 56859) [x86_64-darwin15]
* `mysql --version` # mysql  Ver 14.14 Distrib 5.7.21, for osx10.11 (x86_64) using  EditLine wrapper

## Installation

1. Install Ruby 2.3.3 if you haven't yet:

       $ rbenv install --skip-existing

2. Install bundler if you haven't yet:

       $ gem install bundler

3. Install gems:

       $ bundle install

4. Edit database configurations:

       $ vi ./config/database.yml

## Usage

- Delete blocks older than 1 month (Dry run):

       $ rake block:purge

- Delete blocks older than 1 month:

       $ rake block:purge DELETED=true

- Use longer timeout in database connections:

       $ rake block:purge TIMEOUT=5000

## Contributing
Bug reports and pull requests are welcome.

## License
coreprotect-ruby is released under the [MIT License](http://opensource.org/licenses/MIT).
