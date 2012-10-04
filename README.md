# Link Checker

This Ruby gem enables you to easily check the links in your web site.  It will scan each ```.html``` or ```.htm``` file and then check each external link within each file.

It will print the file path in green if all of the external links check out, and red if there are any problems.  If there are any problems then it will list each problem URL.  It will display yellow warnings for URLs that redirect to other URLs that are good, or red errors if the redirect does not lead to a good URL.

## Installation

Add the ```link-checker``` gem to your project's ```Gemfile```:

    gem "link-checker"

Then ```bundle install``` to install the gem.

## Usage

You can use the ```check-links``` command to specify any directory to scan for HTML files.

For example, to check the links for an Octopress site:

    check-links 'public'

To check the links for a Jekyll site:

    check-links

## Testing

The ```link-checker``` gem uses [RSpec](http://rspec.info) for testing and has 100% test coverage, verified using [simplecov](https://github.com/colszowka/simplecov).

Run the specs with:

    rake spec