require 'spec_helper'
require 'link_checker'

describe LinkChecker do

  before(:all) do
    @site_path = 'spec/test-site/public/'
  end

  it "finds all of the HTML files in the target path." do
    files = LinkChecker.new(@site_path).find_html_files
    files.size.should == 3
  end

  it "finds all of the external links in an HTML file." do
    links = LinkChecker.find_external_links(
      'spec/test-site/public/blog/2012/10/02/a-list-of-links/index.html')
    links.size.should == 4
  end

  describe "checks links and" do

    before(:all) do
      @good_uri = 'http://goodlink.com'
      FakeWeb.register_uri(:any, @good_uri, :body => "Yay it worked.")

      @bad_uri = 'http://brokenlink.com'
      FakeWeb.register_uri(:get, @bad_uri,
        :body => "File not found", :status => ["404", "Missing"])

      @redirect_uri = 'http://redirect.com'
    end

    it "declares good links to be good." do
      LinkChecker.check_link(@good_uri).should be true
    end

    it "declares bad links to be bad." do
      expect { LinkChecker.check_link(@bad_uri) }.to(
        raise_error(LinkChecker::Error))
    end

    describe "follows redirects to the destination and" do

      it "declares good redirect targets to be good." do
        FakeWeb.register_uri(:get, @redirect_uri,
          :location => @good_uri, :status => ["302", "Moved"])
        LinkChecker.check_link(@redirect_uri).should be true
      end

      it "declares bad redirect targets to be bad." do
        FakeWeb.register_uri(:get, @redirect_uri,
          :location => @bad_uri, :status => ["302", "Moved"])
        expect { LinkChecker.check_link(@redirect_uri) }.to(
          raise_error(LinkChecker::Error))
      end

    end

  end

  describe "prints output" do

    it "prints green when the links are all good." do
      LinkChecker.stub(:check_link) { true }
      $stdout.should_receive(:puts).with(/Checked/i).exactly(3).times
      LinkChecker.new(@site_path).check_links
    end

    it "prints green when the links are all bad." do
      LinkChecker.stub(:check_link).and_raise LinkChecker::Error.new('blah')
      $stdout.should_receive(:puts).with(/Problem/i).exactly(3).times
      $stdout.should_receive(:puts).with(/Link/i).at_least(3).times
      $stdout.should_receive(:puts).with(/Response/i).at_least(3).times
      LinkChecker.new(@site_path).check_links
    end

  end

end