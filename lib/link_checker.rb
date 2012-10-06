require 'find'
require 'nokogiri'
require 'net/http'
require 'net/https'
require 'uri'
require 'colorize'
require 'anemone'

class LinkChecker

  def initialize(params)
    @options = params[:options] || {}
    @target =  params[:target] || './'
    @return_code = 0
  end

  def html_file_paths
    Find.find(@target).map {|path|
      FileTest.file?(path) && (path =~ /\.html?$/) ? path : nil
    }.reject{|path| path.nil?}
  end

  def self.external_link_uri_strings(source)
    Nokogiri::HTML(source).css('a').select {|link|
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
    begin
      if @target =~ /^https?\:\/\//
        check_uris_by_crawling
      else
        check_uris_in_files
      end
    rescue => error
      puts "Error: #{error.to_s}".red
    end
    @return_code
  end

  def check_uris_by_crawling
    threads = []
    Anemone.crawl(@target) do |anemone|
      anemone.storage = Anemone::Storage.PStore('link-checker-crawled-pages.pstore')
      anemone.on_every_page do |crawled_page|
        raise StandardError.new(crawled_page.error) if crawled_page.error
        threads << start_link_check_thread(crawled_page.body, crawled_page.url.to_s)
      end
    end
    threads.each{|thread| thread.join }
  end

  def check_uris_in_files
    threads = []
    html_file_paths.each do |file|
      threads << start_link_check_thread(open(file), file)
    end
    threads.each{|thread| thread.join }
  end

  def start_link_check_thread(source, source_name)
    Thread.new do
      results = self.class.external_link_uri_strings(source).map do |uri_string|
        begin
          uri = URI(uri_string)
          response = self.class.check_uri(uri)
          { :uri_string => uri_string, :response => response }
        rescue => error
          { :uri_string => uri_string, :response => Error.new(:error => error.to_s) }
        end
      end
      report_results(source_name, results)
    end
  end
      
  def report_results(file, results)
    errors = results.select{|result| result[:response].class.eql? Error}
    warnings = results.select{|result| result[:response].class.eql? Redirect}
    @return_code = 1 unless errors.empty?
    if @options[:warnings_are_errors]
      @return_code = 1 unless warnings.empty?
      errors = errors + warnings
      warnings = []
    end
    Thread.exclusive do
      if errors.empty?
        message = "Checked: #{file}"
        if warnings.empty? || @options[:no_warnings]
          puts message.green
        else
          puts message.yellow
        end
        unless @options[:no_warnings]
          warnings.each do |warning|
            puts "   Warning: #{warning[:uri_string]}".yellow
            puts "     Redirected to: #{warning[:response].final_destination_uri_string}".yellow
          end
        end
      else
        puts "Problem: #{file}".red
        errors.each do |check|
          puts "   Link: #{check[:uri_string]}".red
          case check[:response]
          when Redirect
            puts "     Redirected to: #{check[:response].final_destination_uri_string}".red
          when Error
            puts "     Response: #{check[:response].error.to_s}".red
          end
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