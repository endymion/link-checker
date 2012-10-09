# Link Checker

This Ruby gem enables you to easily check the links in your web site.  It will scan each ```.html``` or ```.htm``` file and then check each external link within each file.

It will print the file path in green if all of the external links check out, and red if there are any problems.  If there are any problems then it will list each problem URL.  It will display yellow warnings for URLs that redirect to other URLs that are good, or red errors if the redirect does not lead to a good URL.

For more detailed information, please see the article [Introducing the link-checker Ruby gem](http://www.ryanalynporter.com/2012/10/06/introducing-the-link-checker-ruby-gem/) on [ryanalynporter.com](http://www.ryanalynporter.com).

## Features

* Scans files for links, or
* Crawls web pages for links
* Multi-threaded (fast) with a --max-threads parameter
* Warnings for links that redirect to valid links
* red/green/yellow colored output
* 100% test coverage
* Works great with Octopress or Jekyll

## Installation

Add the ```link-checker``` gem to your project's ```Gemfile```:

    gem "link-checker"

Then ```bundle install``` to install the gem.

## Usage

You can use the ```check-links [PATH]``` command to specify any directory to scan for HTML files.  The default path is ```./```.

For example, to check the links for an Octopress site:

    check-links 'public'

To check the links for a Jekyll site:

    check-links

To crawl a live web site:

	check-links 'http://your-site.com'

## Return value

The ```check-links``` command will return a successful return value if there are no problems, or it will return an not-successful return code if it finds errors.  So you can use the return code to make decisions on the command line.  For example:

    check-links 'public' && echo 'SUCCESS'

## Parameters

If you don't want to see yellow warnings for URLs that redirect to valid URLs, then pass the ```--no-warnings``` parameter:

   check-links 'public' --no-warnings

If you want those redirects to be considered errors, even if they redirect to good URLs, then pass the ```--warnings-are-errors``` parameter:

    check-links 'public' --warnings-are-errors

The link checker will spawn a new thread for each HTML file, and a new thread for each link within each HTML file.  That will get out of hand very quickly if you have a large site, so there is a maximum number of threads.  When the maximum number is reached, it will block and wait for an existing thread to complete before spawning a new one.  The default maximum threads setting is 100, but you can control that number with the ```--max-threads``` parameter:

    check-links 'public' --max-threads 500

...or:

    check-links 'public' --max-threads 1

## Testing

The ```link-checker``` gem uses [RSpec](http://rspec.info) for testing and has 100% test coverage, verified using [simplecov](https://github.com/colszowka/simplecov).

Run the specs with:

    rake spec

## API Documentation

The Yardoc documenation is hosted on [RubyDoc.info](http://rubydoc.info/github/endymion/link-checker/frames).