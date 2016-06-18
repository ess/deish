# deish #

This library provides some handy Bash functions for use in troubleshooting issues that arise on Deis v1 clusters.

## Installation ##

Haven't figured out how to express the installation process yet, as a few design decisions are bouncing around.

For the moment, just drop `deish.sh` into a location that both core and root can read.

## Usage ##

The functions provided in `deish.sh` are documented in the source. Effectively, you'll just want to `source /path/to/deish.sh` so you can then use the functions defined within.

## Development ##

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing ##

1. Fork it ( https://github.com/ess/deish/fork )
2. Create your feature branch off of develop (`git checkout develop ; git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
