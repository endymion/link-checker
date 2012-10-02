require 'find'

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

end