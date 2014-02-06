require 'spec_helper'
require 'link_checker'

describe LinkChecker do

  describe "scans a file path and" do

    before(:all) do
      @site_path = 'spec/test-site/public/'
    end

    it "finds all of the HTML files in the target path." do
      files = LinkChecker.new(:target => @site_path).html_file_paths
      files.size.should == 4
    end

    it "finds all of the external links in an HTML file." do
      links = LinkChecker.external_link_uri_strings(
        open('spec/test-site/public/blog/2012/10/07/some-good-links/index.html'))
      links.size.should == 4
    end

    it "finds all of the external links in a string." do
      links = LinkChecker.external_link_uri_strings(
        open('spec/test-site/public/blog/2012/10/07/some-good-links/index.html').read)
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

    it 'declares malformed links to be bad' do
      # Example: http://www.yakimacounty.us/assessor/assessor.htm redirects to %2fassessor%2fDefault.aspx%3fAspxAutoDetectCookieSupport%3d1
      # which causes everything to crash
      malformed_uri = URI('%2fassessor%2fDefault.aspx%3fAspxAutoDetectCookieSupport%3d1')
      LinkChecker.check_uri(malformed_uri).class.should be LinkChecker::Error
    end

    describe "follows redirects to the destination and" do

      it "declares good redirect targets to be good." do
        FakeWeb.register_uri(:get, @redirect_uri.to_s,
          :location => @good_uri.to_s, :status => ["302", "Moved"])
        result = LinkChecker.check_uri(@redirect_uri)
        result.class.should be LinkChecker::Redirect
        result.final_destination_uri_string.should == @good_uri.to_s
      end

      it "declares bad redirect targets to be bad." do
          FakeWeb.register_uri(:get, @redirect_uri.to_s,
            :location => @bad_uri.to_s, :status => ["302", "Moved"])
        result = LinkChecker.check_uri(@redirect_uri)
        result.class.should be LinkChecker::Error
      end

    end

    describe "follow relative redirects for and" do

      it "declares the final target to be good." do
        # Redirect from www.relative to relative.com.
        www_relative_com = URI('http://www.relative.com/somewhere')
        relative_com = URI('http://relative.com/somewhere')
      	FakeWeb.register_uri(:get, www_relative_com.to_s,
          :location => relative_com.to_s, :status => ["302", "Moved"])
        # Then relative redirect to /somewhere/else
      	FakeWeb.register_uri(:get, relative_com.to_s,
      	  :location => '/somewhere/else/', :status => ["302", "Moved"])
        destination = URI('http://relative.com/somewhere/else/')
      	FakeWeb.register_uri(:get, destination.to_s, :body => 'Yay, it worked!')
        result = LinkChecker.check_uri(www_relative_com)
        result.class.should be LinkChecker::Redirect
        result.final_destination_uri_string.should == destination.to_s
      end
    end

  end

  describe "url file processing" do

    it "calls the correct function if filename parameter is passed in." do
      LinkChecker.any_instance.should_receive(:check_uris_from_file).with('whatever.txt')
      LinkChecker.new(:options => { :filename => 'whatever.txt' }).check_uris
    end

    it "validates links located in file" do
      File.should_receive(:open).with('whatever.txt','r') do
        link_file = double('link_file')
        link_file.should_receive(:each_line).and_yield("http://some-target.com\n")
        link_file.should_receive(:close)
        link_file
      end

      FakeWeb.register_uri(:any, 'http://some-target.com', :body => "Yay it worked.")
      LinkChecker.stub(:check_uri) do
        LinkChecker::Good.new(:uri_string => 'http://something.com')
      end
      $stdout.should_receive(:puts).with(/Checked\: http/).once
      $stdout.should_receive(:puts).with(/Checked 1 link in 1 HTML file and found no errors/)
      LinkChecker.new(:options => { :filename => 'whatever.txt' }).check_uris
    end

  end

  describe "url processing from activerecord" do

    it "retrieves url from activerecord" do
      url_attribute = 'url'

      url_record = double('url_record')
      url_record.should_receive(url_attribute).and_return('http://www.example.com')

      url_records_query = double('url_records_query')
      url_records_query.should_receive(:each).and_yield(url_record)

      check_uri = double('check_uri')
      check_uri.should_receive(:join)
      LinkChecker.any_instance.should_receive(:check_uri).and_return(check_uri)

      LinkChecker.new(:options => {}).check_uris_from_activerecord(url_records_query, url_attribute)
    end

    it "processes the url if no block given" do
      url_attribute = 'url'

      url_record = double('url_record')
      url_record.should_receive(url_attribute).and_return('http://www.example.com')

      url_records_query = double('url_records_query')
      url_records_query.should_receive(:each).and_yield(url_record)

      FakeWeb.register_uri(:any, 'http://example.com', :body => "Yay it worked.")
      LinkChecker.stub(:check_uri) do
        LinkChecker::Good.new(:uri_string => 'http://something.com')
      end
      $stdout.should_receive(:puts).with(/Checked\: http/).once

      LinkChecker.new(:options => {}).check_uris_from_activerecord(url_records_query, url_attribute)
    end

    it "calls the block if provided with the results of the uri check" do
      url_attribute = 'url'

      url_record = double('url_record')
      url_record.should_receive(url_attribute).and_return('http://www.example.com')

      url_records_query = double('url_records_query')
      url_records_query.should_receive(:each).and_yield(url_record)

      FakeWeb.register_uri(:any, 'http://example.com', :body => "Yay it worked.")
      
      expected_link_status = LinkChecker::Good.new(:uri_string => 'http://something.com')
      LinkChecker.stub(:check_uri) do
        expected_link_status
      end
      $stdout.should_receive(:puts).with(/Checked\: http/).once

      LinkChecker.new(:options => {}).check_uris_from_activerecord(url_records_query, url_attribute) { |url, response|
        url.should == url_record
        response.should == expected_link_status
      }
    end

  end

  describe "scans a file path and prints output" do

    before(:each) do
      LinkChecker.any_instance.stub(:html_file_paths) {
        ['spec/test-site/public/blog/2012/10/07/some-good-links/index.html'] }
      LinkChecker.stub(:external_link_uri_strings).and_return(
        (1..20).map{|i| "http://something-#{i}.com" } )
    end

    it "prints green when the links are good." do
      LinkChecker.stub(:check_uri) do
        sleep 0.5 # Make LinkChecker#wait_to_spawn_thread wait a little.
        LinkChecker::Good.new(:uri_string => 'http://something.com')
      end
      $stdout.should_receive(:puts).with(/Checked\: .*\.html/).once
      $stdout.should_receive(:puts).with(/Checked 20 links in 1 HTML file and found no errors/)
      LinkChecker.new(
        :target => @site_path,
        # This is to make sure that the entire LinkChecker#wait_to_spawn_thread gets hit during testing.
        :options => { :max_threads => 1 }
      ).check_uris.should == 0 # Return value: good
    end

    it "prints red when the links are bad." do
      LinkChecker.stub(:check_uri) do
        LinkChecker::Error.new(
          :uri_string => 'http://something.com',
          :error => 'No.'
        )
      end
      $stdout.should_receive(:puts).with(/Problem\: .*\.html/).once
      $stdout.should_receive(:puts).with(/Link\: http/).exactly(20).times
      $stdout.should_receive(:puts).with(/Response/).exactly(20).times
      $stdout.should_receive(:puts).with(/Checked 20 links in 1 HTML file and found 20 errors/)
      LinkChecker.new(:target => @site_path).check_uris.should == 1 # Return value: error
    end

    it "prints yellow warnings when the links redirect." do
      LinkChecker.stub(:check_uri) do
        LinkChecker::Redirect.new(
          :uri_string => 'http://something.com',
          :final_desination => 'http://something-else.com'
        )
      end
      $stdout.should_receive(:puts).with(/Checked\: .*\.html/).once
      $stdout.should_receive(:puts).with(/Warning/).exactly(20).times
      $stdout.should_receive(:puts).with(/Redirected/).exactly(20).times
      $stdout.should_receive(:puts).with(/Checked 20 links in 1 HTML file and found no errors/)
      LinkChecker.new(:target => @site_path).check_uris.should == 0 # Return value: good
    end

    it "prints errors when there are warnings with the --warnings_are_errors option." do
      LinkChecker.stub(:check_uri) do
        LinkChecker::Redirect.new(
          :uri_string => 'http://something.com',
          :final_destination_uri_string => 'http://something-else.com'
        )
      end
      $stdout.should_receive(:puts).with(/Problem\: .*\.html/).once
      $stdout.should_receive(:puts).with(/Link/).exactly(20).times
      $stdout.should_receive(:puts).with(/Redirected/).exactly(20).times
      $stdout.should_receive(:puts).with(/Checked 20 links in 1 HTML file and found 20 errors/)
      LinkChecker.new(
        :target => @site_path,
        :options => { :warnings_are_errors => true }
      ).check_uris.should == 1 # Return value: error
    end

    it "does not print warnings when the links redirect with the --no-warnings option." do
      LinkChecker.stub(:check_uri) do
        LinkChecker::Redirect.new(
          :uri_string => 'http://something.com',
          :final_destination_uri_string => 'http://something-else.com'
        )
      end
      $stdout.should_receive(:puts).with(/Checked\: .*\.html/).once
      $stdout.should_receive(:puts).with(/Warning/).exactly(20).times
      $stdout.should_receive(:puts).with(/Redirected/).exactly(20).times
      $stdout.should_receive(:puts).with(/Checked 20 links in 1 HTML file and found no errors/)
      LinkChecker.new(:target => @site_path).check_uris.should == 0 # Return value: good
    end

  end

  describe "prints output for invalid links and" do

    it "declares them to be bad." do
      LinkChecker.stub(:external_link_uri_strings).and_return(
        ['hQQp://!!!.com', 'hOOp://???.com'])
      $stdout.should_receive(:puts).with(/Problem\: .*\.html/).once
      $stdout.should_receive(:puts).with(/Link/).twice
      $stdout.should_receive(:puts).with(/Response/).twice
      thread = LinkChecker.new(:target => @site_path).check_page('<html></html>', 'source.html')
      thread.join
    end

  end

  it "crawls a web site." do
    FakeWeb.register_uri(:any, 'http://some-target.com', :body => "Yay it worked.")
    LinkChecker.stub(:external_link_uri_strings).and_return(['http://something.com'])
    LinkChecker.stub(:check_uri) do
      LinkChecker::Good.new(:uri_string => 'http://something.com')
    end
    $stdout.should_receive(:puts).with(/Checked\: http/).once
    $stdout.should_receive(:puts).with(/Checked 1 link in 1 HTML file and found no errors/)
    LinkChecker.new(:target => 'http://some-target.com').check_uris
  end

  describe "produces useful return codes when" do

    it "the target file does not exist." do
      Find.stub(:find).and_raise(Errno::ENOENT.new('test'))
      $stdout.should_receive(:puts).with(/Error/i).once
      LinkChecker.new(:target => 'does-not-exist').check_uris
    end

    it "the target file does not exist." do
      FakeWeb.allow_net_connect = false
      $stdout.should_receive(:puts).with(/Error/i).once
      LinkChecker.new(:target => 'http://does-not-exist.com').check_uris
    end

  end

end
