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

  def self.external_link_uri_strings(file_path)
    Nokogiri::HTML(open(file_path)).css('a').select {|link|
        !link.attribute('href').nil? &&
        link.attribute('href').value =~ /^https?\:\/\//
    }.map{|link| link.attributes['href'].value}
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
            return Redirect.new(:final_destination_uri_string => uri.to_s)
          else
            return Good.new(:uri_string => uri.to_s)
          end
        when Net::HTTPRedirection then
          return self.check_uri(URI(response['location']), true)
        else
          return Error.new(:uri_string => uri.to_s, :response => response)
        end
      end
    end
  end

  def check_uris
    if @target =~ /^https?\:\/\//
      check_uris_by_crawling
    else
      check_uris_in_files
    end
  end

  def check_uris_in_files
    threads = []
    html_file_paths.each do |file|
      threads << Thread.new do
        results = self.class.external_link_uri_strings(file).map do |uri_string|
          begin
            uri = URI(uri_string)
            response = self.class.check_uri(uri)
            { :uri_string => uri_string, :response => response }
          rescue => error
            { :uri_string => uri_string, :response => Error.new(:error => error.to_s) }
          end
        end
        report_results(file, results)
      end
    end
    threads.each{|thread| thread.join }
  end
      
  def report_results(file, results)
    bad_checks = results.select{|result| result[:response].class.eql? Error}
    warnings = results.select{|result| result[:response].class.eql? Redirect}
    Thread.exclusive do
      if bad_checks.empty?
        message = "Checked: #{file}"
        if warnings.empty?
          puts message.green
        else
          puts message.yellow
        end
        warnings.each do |warning|
          puts "   Warning: #{warning[:uri_string]}".yellow
          puts "     Redirected to: #{warning[:response].final_destination_uri_string}".yellow
        end
      else
        puts "Problem: #{file}".red
        bad_checks.each do |check|
          puts "   Link: #{check[:uri_string]}".red
          puts "     Response: #{check[:response].error.to_s}".red
        end
      end
    end
  end

  class Result
    attr_reader :uri_string
    def initialize(params)
      @uri_string = params[:uri_string]
    end
  end

  class Good < Result
  end

  class Redirect < Result
    attr_reader :good
    attr_reader :final_destination_uri_string
    def initialize(params)
      @final_destination_uri_string = params[:final_destination_uri_string]
      @good = params[:good]
      super(params)
    end
  end

  class Error < Result
    attr_reader :error
    def initialize(params)
      @error = params[:error]
    end
  end

end