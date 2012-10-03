require 'find'
require 'nokogiri'
require 'net/http'
require 'net/https'
require 'uri'

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
      external_links = all_links.select{|link| link.attribute('href').value =~ /^https?\:\/\// }
    end

    def self.check_link(uri)
      response =
        if uri =~ /^http\:/
          Net::HTTP.get_response(URI.parse(uri))
        else
          uri = URI.parse(uri)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true if uri.scheme == "https"  # enable SSL/TLS
          http.start {
            http.request_get(uri.path) {|response|
              response
            }
          }
        end

      case response
      when Net::HTTPSuccess then
        return true
      when Net::HTTPRedirection then
        return self.check_link(response['location'])
      else
        raise Error.new(response)
      end
    end

    def check_links
      find_html_files.each do |file|
        bad_checks = []  

        self.class.find_external_links(file).each do |link|
          uri = link.attribute('href').value

          begin          
            self.class.check_link(uri)
          rescue => error
            bad_checks << { :link => link, :error => error }
          end
        end
        
        if bad_checks.empty?
          puts "Checked: #{file}".green
        else
          puts "Problem: #{file}".red
          bad_checks.each do |check|
            puts "   Link: #{check[:link].attribute('href').value}".red
            puts "     Response: #{check[:error].response.inspect}".red
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