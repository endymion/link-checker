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
    FakeWeb.register_uri(:any, "http://goodlink.com",
      :body => "Yay it worked.")
    FakeWeb.register_uri(:get, "http://brokenlink.com",
      :body => "File not found", :status => ["404", "Missing"])

    Net::HTTP.get_response(URI.parse("http://goodlink.com"))
  end

end