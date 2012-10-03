# Octopress Link Checker

This Ruby gem allows you to easily check the links in your Octopress web site.

## Installation

Add the ```link-checker``` gem to your project's ```Gemfile```:

    gem "link-checker"

Then ```bundle install``` to install the gem.

## Usage

You can use the ```check-links``` command to specify any directory to scan for HTML files.  It will scan each ```.html``` or ```.htm``` file and then check each link within each file.

For example, to check the links for a Jekyll or Octopress site:

    check-links 'public'

## Testing

The ```link-checker``` gem uses [RSpec](http://rspec.info) for testing and has 100% test coverage, verified using [simplecov](https://github.com/colszowka/simplecov).

Run the specs with:

    rake spec