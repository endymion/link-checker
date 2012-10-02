require 'spec_helper'
require 'octopress-check-links'

describe OctopressLinkChecker, "Link checker" do

  it "finds all of the HTML files in the Octopress site" do
    files = OctopressLinkChecker.find_html_files('spec/test-site/public')
    files.size.should == 3
  end

  it "finds all of the external links in an HTML file" do
    links = OctopressLinkChecker.find_external_links(
      'spec/test-site/public/blog/2012/10/02/a-list-of-links/index.html')
    links.size.should == 4
  end

  it "checks links" do
    good_uri = 'http://goodlink.com'
    FakeWeb.register_uri(:any, good_uri, :body => "Yay it worked.")
    OctopressLinkChecker.check_link(good_uri).should be true

    bad_uri = 'http://brokenlink.com'
    FakeWeb.register_uri(:get, bad_uri,
      :body => "File not found", :status => ["404", "Missing"])
    OctopressLinkChecker.check_link(bad_uri).should_not be true    
  end

end