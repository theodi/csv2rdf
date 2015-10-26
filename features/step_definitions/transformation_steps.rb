Given(/^I have a CSV file called "(.*?)"$/) do |filename|
  @csv = File.read( File.join( File.dirname(__FILE__), "..", "fixtures", filename ) )
end

Given(/^it has a Link header holding "(.*?)"$/) do |link|
  @link = "#{link}; type=\"application/csvm+json\""
end

Given(/^it is stored at the url "(.*?)"$/) do |url|
  @url = url
  content_type = @content_type || "text/csv"
  charset = @encoding || "UTF-8"
  headers = {"Content-Type" => "#{content_type}; charset=#{charset}"}
  headers["Link"] = @link if @link
  stub_request(:get, url).to_return(:status => 200, :body => @csv, :headers => headers)
  stub_request(:get, URI.join(url, '/.well-known/csvm')).to_return(:status => 404)
  stub_request(:get, url + '-metadata.json').to_return(:status => 404)
  stub_request(:get, URI.join(url, 'csv-metadata.json')).to_return(:status => 404)
end

Given(/^I have a metadata file called "([^"]*)"$/) do |filename|
  @schema_type = :csvw_metadata
  @schema_json = File.read( File.join( File.dirname(__FILE__), "..", "fixtures", filename ) )
end

Given(/^the (schema|metadata) is stored at the url "(.*?)"$/) do |schema_type,schema_url|
  @schema_url = schema_url
  stub_request(:get, @schema_url).to_return(:status => 200, :body => @schema_json.to_str)
end

Given(/^I have a file called "(.*?)" at the url "(.*?)"$/) do |filename,url|
  content = File.read( File.join( File.dirname(__FILE__), "..", "fixtures", filename ) )
  content_type = filename =~ /.csv$/ ? "text/csv" : "application/csvm+json"
  stub_request(:get, url).to_return(:status => 200, :body => content, :headers => {"Content-Type" => "#{content_type}; charset=UTF-8"})
end

Given(/^there is no file at the url "(.*?)"$/) do |url|
  stub_request(:get, url).to_return(:status => 404)
end

When(/^I transform the CSV into RDF( in minimal mode)?$/) do |minimal|
  @csv_options ||= default_csv_options
  minimal = minimal == " in minimal mode"

  begin
    if @schema_json
      json = JSON.parse(@schema_json)
      if @schema_type == :json_table
        @schema = Csvlint::Schema.from_json_table( @schema_url || "http://example.org ", json )
      else
        @schema = Csvlint::Schema.from_csvw_metadata( @schema_url || "http://example.org ", json )
      end
    end

    transformer = Csvlint::Csvw::Csv2Rdf.new( @url, @csv_options, @schema, { :minimal => minimal } )
    @rdf = transformer.result
    @errors = transformer.errors
    @warnings = transformer.warnings
  rescue JSON::ParserError => e
    @errors = [e]
  rescue Csvlint::Csvw::MetadataError => e
    @errors = [e]
  end
end

Then(/^the RDF should match that in "(.*?)"$/) do |filename|
  expected = RDF::Graph.load( File.join( File.dirname(__FILE__), "..", "fixtures", filename ), format: :ttl )
  actual = @rdf
  actual_writer = RDF::Writer.for(:ttl)
  expected_writer = RDF::Writer.for(:ttl)
  actual_ttl = actual_writer.dump(actual, nil, { :standard_prefixes => true, :canonicalize => true, :literal_shorthand => true })
  expected_ttl = expected_writer.dump(expected, nil, { :standard_prefixes => true, :canonicalize => true, :literal_shorthand => true })
  expect(actual_ttl).to eq(expected_ttl)
end

Then(/^there should be errors$/) do
  # this test is only used for CSVW testing; :invalid_encoding & :line_breaks mask lack of real errors
  @errors.delete_if { |e| e.instance_of?(Csvlint::ErrorMessage) && [:invalid_encoding, :line_breaks].include?(e.type) }
  expect( @errors.count ).to be > 0
end

Then(/^there should not be errors$/) do
  expect( @errors.count ).to eq(0)
end

Then(/^there should be warnings$/) do
  expect( @warnings.count ).to be > 0
end

Then(/^there should not be warnings$/) do
  # this test is only used for CSVW testing, and :inconsistent_values warnings don't count in CSVW
  @warnings.delete_if { |w| [:inconsistent_values, :check_options].include?(w.type) }
  expect( @warnings.count ).to eq(0)
end
