require 'find'
require 'nokogiri'
require 'net/http'
require 'net/https'
require 'uri'
require 'colorize'
require 'anemone'

class LinkChecker

  # Create a new instance of LinkChecker
  #
  # @param params [Hash] A hash containing the :target value, which can represent either
  #   a file path or a URL.  And an optional :options value, which contains a hash with a
  #   list of possible optional paramters.  This can include :no_warnings, :warnings_are_errors,
  #   or :max_threads
  def initialize(params)
    @options = params[:options] || { }
    @target =  params[:target] || './'

    @html_files = []
    @links = []
    @errors = []
    @warnings = []
    @return_code = 0

    @options[:max_threads] ||= 100
  end

  # Find a list of HTML files in the @target path, which was set in the {#initialize} method.
  def html_file_paths
    Find.find(@target).map {|path|
      FileTest.file?(path) && (path =~ /\.html?$/) ? path : nil
    }.reject{|path| path.nil? }
  end

  # Find a list of all external links in the specified target, represented as URI strings.
  #
  # @param source [String] Either a file path or a URL.
  # @return [Array] A list of URI strings.
  def self.external_link_uri_strings(source)
    Nokogiri::HTML(source).css('a').select {|link|
        !link.attribute('href').nil? &&
        link.attribute('href').value =~ /^https?\:\/\//
    }.map{|link| link.attributes['href'].value }
  end

  # Check one URL.
  #
  # @param uri [URI] A URI object for the target URL.
  # @return [LinkChecker::Result] One of the following objects: {LinkChecker::Good},
  #   {LinkChecker::Redirect}, or {LinkChecker::Error}.
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
          return Error.new(:uri_string => uri.to_s, :error => response)
        end
      end
    end
  end

  # Check the URLs in the @target, either using {#check_uris_by_crawling} or
  # {#check_uris_in_files}, depending on whether the @target looks like an http:// URL or
  # a file path.
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

    # Report the final results.
    unless @html_files.empty?
      file_pluralized = (@html_files.size.eql? 1) ? 'file' : 'files'
      link_pluralized = (@links.size.eql? 1) ? 'link' : 'links'
      if @errors.empty?
        puts ("Checked #{@links.size} #{link_pluralized} in #{@html_files.size} " +
          "HTML #{file_pluralized} and found no errors.").green
      else
        error_pluralized = (@errors.size.eql? 1) ? 'error' : 'errors'
        puts ("Checked #{@links.size} #{link_pluralized} in #{@html_files.size} " +
          "HTML #{file_pluralized} and found #{@errors.size} #{error_pluralized}.").red
      end
    end

    @return_code
  end

  # Use {http://anemone.rubyforge.org Anemone} to crawl the pages at the @target URL,
  # and then check all of the external URLs in those pages.
  def check_uris_by_crawling
    threads = []
    Anemone.crawl(@target) do |anemone|
      anemone.storage = Anemone::Storage.PStore('link-checker-crawled-pages.pstore')
      anemone.on_every_page do |crawled_page|
        raise StandardError.new(crawled_page.error) if crawled_page.error
        threads << check_page(crawled_page.body, crawled_page.url.to_s)
        @html_files << crawled_page
      end
    end
    threads.each{|thread| thread.join }
  end

  # Treat the @target as a file path and find all HTML files under that path, and then
  # scan all of the external URLs in those files.
  def check_uris_in_files
    threads = []
    html_file_paths.each do |file|
      wait_to_spawn_thread
      threads << check_page(open(file), file)
      @html_files << file
    end
    threads.each{|thread| thread.join }
  end

  # Spawn a thread to check an HTML page, and then spawn a thread for checking each
  # link within that page.
  #
  # @param source [String] The contents of the HTML page, as a string.
  # @param source_name [String] The name of the source, which will be reported if
  # there is an error or a warning.
  def check_page(page, page_name)
    Thread.new do
      threads = []
      results = []
      self.class.external_link_uri_strings(page).each do |uri_string|
        Thread.exclusive { @links << page }
        wait_to_spawn_thread
        threads << Thread.new do
          begin
            uri = URI(uri_string)
            response = self.class.check_uri(uri)
            response.uri_string = uri_string
            Thread.exclusive { results << response }
          rescue => error
            Thread.exclusive { results <<
              Error.new( :error => error.to_s, :uri_string => uri_string) }
          end
        end
      end
      threads.each {|thread| thread.join }
      report_results(page_name, results)
    end
  end
  
  # Report the results of scanning one HTML page.
  #
  # @param page_name [String] The name of the page.
  # @param results [Array] An array of {LinkChecker::Result} objects.
  def report_results(page_name, results)
    errors = results.select{|result| result.class.eql? Error}
    warnings = results.select{|result| result.class.eql? Redirect}
    @return_code = 1 unless errors.empty?
    if @options[:warnings_are_errors]
      @return_code = 1 unless warnings.empty?
      errors = errors + warnings
      warnings = []
    end
    Thread.exclusive do
      # Store the results in the LinkChecker instance.
      # This must be thread-exclusive to avoid a race condition.
      @errors = @errors.concat(errors)
      @warnings = @warnings.concat(warnings)

      if errors.empty?
        message = "Checked: #{page_name}"
        if warnings.empty? || @options[:no_warnings]
          puts message.green
        else
          puts message.yellow
        end
        unless @options[:no_warnings]
          warnings.each do |warning|
            puts "   Warning: #{warning.uri_string}".yellow
            puts "     Redirected to: #{warning.final_destination_uri_string}".yellow
          end
        end
      else
        puts "Problem: #{page_name}".red
        errors.each do |error|
          puts "   Link: #{error.uri_string}".red
          case error
          when Redirect
            puts "     Redirected to: #{error.final_destination_uri_string}".red
          when Error
            puts "     Response: #{error.error.to_s}".red
          end
        end
      end
    end
  end

  # Abstract base class for representing the results of checking one URI.
  class Result
    attr_accessor :uri_string

    # A new LinkChecker::Result object instance.
    #
    # @param params [Hash] A hash of parameters.  Expects :uri_string.
    def initialize(params)
      @uri_string = params[:uri_string]
    end
  end

  # A good result.  The URL is valid.
  class Good < Result
  end

  # A redirection to another URL.
  class Redirect < Result
    attr_reader :good
    attr_reader :final_destination_uri_string

    # A new LinkChecker::Redirect object.
    #
    # @param params [Hash] A hash of parameters.  Expects :final_destination_uri_string,
    # which is the URL that the original :uri_string redirected to.
    def initialize(params)
      @final_destination_uri_string = params[:final_destination_uri_string]
      @good = params[:good]
      super(params)
    end
  end

  # A bad result.  The URL is not valid for some reason.  Any reason, other than a 200
  # HTTP response.
  #
  # @param params [Hash] A hash of parameters.  Expects :error, which is a string
  # representing the error.
  class Error < Result
    attr_reader :error
    def initialize(params)
      @error = params[:error]
      super(params)
    end
  end

  private

  # Checks the current :max_threads setting and blocks until the number of threads is
  # below that number.
  def wait_to_spawn_thread
    # Never spawn more than the specified maximum number of threads.
    until Thread.list.select {|thread| thread.status == "run"}.count <
      (1 + @options[:max_threads]) do
      # Wait 5 milliseconds before trying again.
      sleep 0.005
    end
  end

end