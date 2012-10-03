require 'find'
require 'nokogiri'
require 'net/http'

module Link

  class Checker

    def initialize(target_path)
      @target_path = target_path
    end

    def find_html_files
      html_files = []
      Find.find(@target_path) do |path|
        if FileTest.directory?(path)
          if File.basename(path)[0] == '..'
            Find.prune
          else
            next
          end
        else
          html_files << path if path =~ /\.html$/
        end
      end
      html_files
    end

    def self.find_external_links(file_path)
      all_links = Nokogiri::HTML(open(file_path)).css('a')
      external_links = all_links.select{|link| link.attribute('href').value =~ /^http/ }
    end

    def self.check_link(uri)
      response = Net::HTTP.get_response(URI.parse(uri))
      return true if response.class.eql? Net::HTTPOK
      raise Error.new(response)
    end

    def check_links
      find_html_files.each do |file|
        bad_links = []  

        self.class.find_external_links(file).each do |link|
          uri = link.attribute('href').value

          begin          
            self.class.check_link(uri)
          rescue => e
            bad_links << [link, e]
          end
        end
        
        if bad_links.empty?
          puts "Checked: #{file}".green
        else
          puts "Problem: #{file}".red
          bad_links.each do |link|
            puts "   Link: #{link.first.attribute('href').value}".red
            puts "     Response: #{link.last.response.inspect}".red
          end
        end

      end

    end

  end

  class Error < StandardError
    attr_accessor :response
    def initialize(response)
      @response = response
    end
  end

end