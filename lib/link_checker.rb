require 'find'
require 'nokogiri'
require 'net/http'
require 'net/https'
require 'uri'
require 'colorize'
require 'anemone'

class LinkChecker

  def initialize(params)
    @options = params[:options] || { }
    @target =  params[:target] || './'

    @html_files = []
    @links = []
    @errors = []
    @warnings = []
    @return_code = 0

    @options[:max_threads] ||= 100 # Only happens in testing.
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
          return Error.new(:uri_string => uri.to_s, :error => response)
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

  def check_uris_by_crawling
    threads = []
    Anemone.crawl(@target) do |anemone|
      anemone.storage = Anemone::Storage.PStore('link-checker-crawled-pages.pstore')
      anemone.on_every_page do |crawled_page|
        raise StandardError.new(crawled_page.error) if crawled_page.error
        threads << start_link_check_thread(crawled_page.body, crawled_page.url.to_s)
        @html_files << crawled_page
      end
    end
    threads.each{|thread| thread.join }
  end

  def check_uris_in_files
    threads = []
    html_file_paths.each do |file|
      wait_to_spawn_thread
      threads << start_link_check_thread(open(file), file)
      @html_files << file
    end
    threads.each{|thread| thread.join }
  end

  def start_link_check_thread(source, source_name)
    Thread.new do
      threads = []
      results = []
      self.class.external_link_uri_strings(source).each do |uri_string|
        Thread.exclusive { @links << source }
        wait_to_spawn_thread
        threads << Thread.new do
          begin
            uri = URI(uri_string)
            response = self.class.check_uri(uri)
            response.uri_string = uri_string
            Thread.exclusive { results << response }
          rescue => error
            Thread.exclusive { results <<
              Error.new(:error => error.to_s, :uri_string => uri_string) }
          end
        end
      end
      threads.each {|thread| thread.join }
      report_results(source_name, results)
    end
  end
      
  def report_results(file, results)
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
        message = "Checked: #{file}"
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
        puts "Problem: #{file}".red
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

  class Result
    attr_accessor :uri_string
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
      super(params)
    end
  end

  private

  def wait_to_spawn_thread
    # Never spawn more than the specified maximum number of threads.
    until Thread.list.select {|thread| thread.status == "run"}.count <
      (1 + @options[:max_threads]) do
      # Wait 5 milliseconds before trying again.
      sleep 0.005
    end
  end

end