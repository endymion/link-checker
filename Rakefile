# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "link-checker"
  gem.homepage = "http://www.ryanalynporter.com/2012/10/06/introducing-the-link-checker-ruby-gem/"
  gem.license = "MIT"
  gem.summary = %Q{Check the links in a web site before deploying.}
  gem.description = %Q{A Ruby gem for checking the links in a web site. Can either scan files or crawl pages. Multi-threaded, with red/green colored output, support for SSL, and support for following redirects. Works great with Octopress, Jekyll, or any collection of static HTML files. With 100% RSpec coverage.}
  gem.authors = ["Ryan Alyn Porter"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core/rake_task'
desc "Run specs"
RSpec::Core::RakeTask.new

require 'yard'
YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/*.rb']
end
