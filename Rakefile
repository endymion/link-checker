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
  gem.name = "octopress-link-checker"
  gem.homepage = "http://github.com/endymion/octopress-link-checker"
  gem.license = "MIT"
  gem.summary = %Q{Check the links in an Octopress web site before deploying.}
  gem.description = %Q{Check the links in an Octopress web site before deploying, using Nokogiri.}
  gem.authors = ["Ryan Alyn Porter"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new
