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

  def html_file_paths
    Find.find(@target).map {|path|
      FileTest.file?(path) && (path =~ /\.html?$/) ? path : nil
    }.reject{|path| path.nil?}
  end

  def self.external_link_uris(file_path)
    Nokogiri::HTML(open(file_path)).css('a').select {|link|
        !link.attribute('href').nil? &&
        link.attribute('href').value =~ /^https?\:\/\//
    }.map{|link| URI(link.attributes['href'].value)}
  end

  def self.check_uri(uri, redirected=false)
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
          return self.check_uri(URI(response['location']), true)
        else
          raise Error.new(response)
        end
      end
    end
  end

  def check_uris
    html_file_paths.each do |file|
      bad_checks = []
      warnings = []
      self.class.external_link_uris(file).each do |uri|
        begin
          response = self.class.check_uri(uri)
          if response.class.eql? Redirect
            warnings << { :uri => uri, :response => response }
          end
        rescue => error
          bad_checks << { :uri => uri, :response => error }
        end
      end
      
      if bad_checks.empty?
        if warnings.empty?
          puts "Checked: #{file}".green
        else
          puts "Checked: #{file}".yellow
        end
        warnings.each do |warning|
          puts "   Warning: #{warning[:uri].to_s}".yellow
          puts "     Redirected to: #{warning[:response].final_destination.to_s}".yellow
        end
      else
        puts "Problem: #{file}".red
        bad_checks.each do |check|
          puts "   Link: #{check[:uri].to_s}".red
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