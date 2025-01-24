# PumaLogStats

Puma plugin to log server stats to puma.log. It logs changes only and can raise Sentry issues when a threshold is reached.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'puma-log_stats'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install puma-log_stats

## Usage

This plugin is loaded using Puma's plugin API. To enable, add a `plugin :log_stats` directive to your Puma config DSL, then configure the `LogStats` object with any additional configuration:

```ruby
# config/puma.rb

plugin :log_stats
# LogStats.interval = 10
# LogStats.notify_change_with = :sentry # can be a Proc
# LogStats.warning_threshold = 0.7
# LogStats.critical_threshold = 0.85
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/codeur/puma-log_stats.
