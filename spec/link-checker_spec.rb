require 'spec_helper'
require 'link_checker'

describe LinkChecker do

  describe "scans a file path and" do

    before(:all) do
      @site_path = 'spec/test-site/public/'
    end

    it "finds all of the HTML files in the target path." do
      files = LinkChecker.new(@site_path).html_file_paths
      files.size.should == 3
    end

    it "finds all of the external links in an HTML file." do
      links = LinkChecker.external_link_uris(
        'spec/test-site/public/blog/2012/10/02/a-list-of-links/index.html')
      links.size.should == 4
    end

  end

  describe "checks links and" do

    before(:all) do
      @good_uri = URI('http://goodlink.com')
      FakeWeb.register_uri(:any, @good_uri.to_s, :body => "Yay it worked.")

      @bad_uri = URI('http://brokenlink.com')
      FakeWeb.register_uri(:get, @bad_uri.to_s,
        :body => "File not found", :status => ["404", "Missing"])

      @redirect_uri = URI('http://redirect.com')
    end

    it "declares good links to be good." do
      LinkChecker.check_uri(@good_uri).class.should be LinkChecker::Good
    end

    it "declares bad links to be bad." do
      LinkChecker.check_uri(@bad_uri).class.should be LinkChecker::Error
    end

    describe "follows redirects to the destination and" do

      it "declares good redirect targets to be good." do
        FakeWeb.register_uri(:get, @redirect_uri.to_s,
          :location => @good_uri.to_s, :status => ["302", "Moved"])
        result = LinkChecker.check_uri(@redirect_uri)
        result.class.should be LinkChecker::Redirect
        result.final_destination.should == @good_uri
      end

      it "declares bad redirect targets to be bad." do
        FakeWeb.register_uri(:get, @redirect_uri.to_s,
          :location => @bad_uri.to_s, :status => ["302", "Moved"])
        result = LinkChecker.check_uri(@redirect_uri)
        result.class.should be LinkChecker::Error
      end

    end

  end

  describe "prints output" do

    before(:each) do
      LinkChecker.any_instance.stub(:html_file_paths).and_return(['somefile.html'])
      LinkChecker.stub(:external_link_uris).and_return([URI('http://something.com')])
    end

    it "prints green when the links are all good." do
      LinkChecker.stub(:check_uri) { LinkChecker::Good.new }
      $stdout.should_receive(:puts).with(/Checked/i).once
      LinkChecker.new(@site_path).check_uris
    end

    it "prints red when the links are all bad." do
      LinkChecker.stub(:check_uri).and_raise LinkChecker::Error.new('blah')
      $stdout.should_receive(:puts).with(/Problem/i).once
      $stdout.should_receive(:puts).with(/Link/i).once
      $stdout.should_receive(:puts).with(/Response/i).once
      LinkChecker.new(@site_path).check_uris
    end

    it "prints yellow warnings when the links redirect." do
      LinkChecker.stub(:check_uri) { LinkChecker::Redirect.new('http://somewhere') }
      $stdout.should_receive(:puts).with(/Checked/i).once
      $stdout.should_receive(:puts).with(/Warning/i).once
      $stdout.should_receive(:puts).with(/Redirected/i).once
      LinkChecker.new(@site_path).check_uris
    end

  end

end