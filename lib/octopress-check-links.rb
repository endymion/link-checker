require 'find'
require 'nokogiri'
require 'net/http'

class OctopressLinkChecker

  def self.find_html_files(target_path)
    html_files = []
    Find.find(target_path) do |path|
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

  def self.find_external_links(target_path)
    all_links = Nokogiri::HTML(open(target_path)).css('a')
    external_links = all_links.select{|link| link.attribute('href').value =~ /^http/ }
  end

  def self.check_link(uri)
    Net::HTTP.get_response(URI.parse(uri)).class.eql? Net::HTTPOK
  end

end