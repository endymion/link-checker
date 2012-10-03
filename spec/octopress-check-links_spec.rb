require 'spec_helper'
require 'octopress-check-links'

describe Link::Checker, "Link checker" do

  it "finds all of the HTML files in the Octopress site" do
    checker = Link::Checker.new('spec/test-site/public')
    files = checker.find_html_files
    files.size.should == 3
  end

  it "finds all of the external links in an HTML file" do
    links = Link::Checker.find_external_links(
      'spec/test-site/public/blog/2012/10/02/a-list-of-links/index.html')
    links.size.should == 4
  end

  it "checks links" do
    good_uri = 'http://goodlink.com'
    FakeWeb.register_uri(:any, good_uri, :body => "Yay it worked.")
    Link::Checker.check_link(good_uri).should be true

    bad_uri = 'http://brokenlink.com'
    FakeWeb.register_uri(:get, bad_uri,
      :body => "File not found", :status => ["404", "Missing"])
    expect { Link::Checker.check_link(bad_uri) }.to raise_error(Link::Error)
  end

end