require 'find'
require 'nokogiri'
require 'net/http'
require 'net/https'
require 'uri'
require 'colorize'

class LinkChecker

  def initialize(target)
    @target = target
  end

  def scan_files_for_links
    self
  end

  def self.find_html_files(target_path)
    Find.find(target_path).map {|path|
      FileTest.file?(path) && (path =~ /\.html?$/) ? path : nil
    }.reject{|path| path.nil?}
  end

  def self.find_external_links(file_path)
    Nokogiri::HTML(open(file_path)).css('a').
      select do |link|
        !link.attribute('href').nil? &&
        link.attribute('href').value =~ /^https?\:\/\//
      end
  end

  def self.check_link(uri, redirected=false)
    uri = URI.parse(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"
    http.start do
      path = (uri.path.empty?) ? '/' : uri.path
      http.request_get(path) do |response|
        case response
        when Net::HTTPSuccess then
          if redirected
            return Redirect.new(uri)
          else
            return Good.new
          end
        when Net::HTTPRedirection then
          return self.check_link(response['location'], true)
        else
          raise Error.new(response)
        end
      end
    end
  end

  def check_links
    self.class.find_html_files(@target_path).each do |file|
      bad_checks = []
      warnings = []
      self.class.find_external_links(file).each do |link|
        uri = link.attribute('href').value
        begin
          response = self.class.check_link(uri)
          if response.class.eql? Redirect
            warnings << { :link => link, :response => response }
          end
        rescue => error
          bad_checks << { :link => link, :response => error }
        end
      end
      
      if bad_checks.empty?
        if warnings.empty?
          puts "Checked: #{file}".green
        else
          puts "Checked: #{file}".yellow
        end
        warnings.each do |warning|
          puts "   Warning: #{warning[:link].attribute('href').value}".yellow
          puts "     Redirected to: #{warning[:response].final_destination.to_s}".yellow
        end
      else
        puts "Problem: #{file}".red
        bad_checks.each do |check|
          puts "   Link: #{check[:link].attribute('href').value}".red
          puts "     Response: #{check[:response].response.inspect}".red
        end
      end
    end
  end

  class Good; end

  class Redirect
    attr_reader :final_destination
    def initialize(final_destination)
      @final_destination = final_destination
    end
  end

  class Error < StandardError
    attr_accessor :response
    def initialize(response)
      @response = response
    end
  end

end