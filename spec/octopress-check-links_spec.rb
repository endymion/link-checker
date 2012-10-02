require 'spec_helper'
require 'octopress-check-links'

describe OctopressLinkChecker, "hello" do

  it "says hello" do
    files = OctopressLinkChecker.find_html_files('spec/test-site/public')
    files.size.should == 3
  end

end