require 'json'
require 'open-uri'
require 'uri'

BASE_URI = "http://www.w3.org/2013/csvw/tests/"
BASE_PATH = File.join(File.dirname(__FILE__), "..", "fixtures", "csvw")
FEATURE_BASE_PATH = File.join(File.dirname(__FILE__), "..")
RDF_TRANSFORMATION_FEATURE_FILE_PATH = File.join(FEATURE_BASE_PATH, "csvw_rdf_transformation_tests.feature")

Dir.mkdir(BASE_PATH) unless Dir.exist?(BASE_PATH)

def cache_file(filename)
	file = File.join(BASE_PATH, filename)
	uri = URI.join(BASE_URI, filename)
	unless File.exist?(file)
		if filename.include? "/"
			levels = filename.split("/")[0..-2]
			for i in 0..levels.length
				dir = File.join(BASE_PATH, levels[0..i].join("/"))
				Dir.mkdir(dir) unless Dir.exist?(dir)
			end
		end
		STDERR.puts("storing #{file} locally")
		File.open(file, 'wb') do |f|
			f.puts "@base <http://www.w3.org/2013/csvw/tests/#{filename}> ." if filename.end_with?(".ttl")
			f.puts open(uri, 'rb').read
		end
	end
	return uri, file
end

File.open(RDF_TRANSFORMATION_FEATURE_FILE_PATH, 'w') do |file|
	file.puts "# Auto-generated file based on standard RDF transformation CSVW tests from http://www.w3.org/2013/csvw/tests/manifest-rdf.jsonld"
	file.puts ""

	manifest = JSON.parse( open("http://www.w3.org/2013/csvw/tests/manifest-rdf.jsonld").read )

	file.puts "Feature: #{manifest["label"]}"
	file.puts ""
	
	manifest["entries"].each do |entry|
		action_uri, action_file = cache_file(entry["action"])
		metadata = nil
		provided_files = []
		missing_files = []
		file.puts "\t# #{entry["id"]}"
		file.puts "\t# #{entry["comment"]}"
		file.puts "\tScenario: #{entry["id"]} #{entry["name"].gsub("<", "less than")}"
		if entry["action"].end_with?(".json")
			file.puts "\t\tGiven I have a metadata file called \"csvw/#{entry["action"]}\""
			file.puts "\t\tAnd the metadata is stored at the url \"#{action_uri}\""
		else
			file.puts "\t\tGiven I have a CSV file called \"csvw/#{entry["action"]}\""
			file.puts "\t\tAnd it has a Link header holding \"#{entry["httpLink"]}\"" if entry["httpLink"]
			file.puts "\t\tAnd it is stored at the url \"#{action_uri}\""
			if entry["option"] && entry["option"]["metadata"]
				# no need to store the file here, as it will be listed in the 'implicit' list, which all get stored
				metadata = URI.join(BASE_URI, entry["option"]["metadata"])
				file.puts "\t\tAnd I have a metadata file called \"csvw/#{entry["option"]["metadata"]}\""
				file.puts "\t\tAnd the metadata is stored at the url \"#{metadata}\""
			end
			provided_files << action_uri.to_s
			if entry["name"].include?("/.well-known/csvm")
				file.puts "\t\tAnd I have a file called \"w3.org/.well-known/csvm\" at the url \"http://www.w3.org/.well-known/csvm\""
	  			missing_files << "#{action_uri}.json"
	  			missing_files << URI.join(action_uri, 'csvm.json').to_s
			else
				missing_files << URI.join(action_uri, '/.well-known/csvm').to_s
			end
  			missing_files << "#{action_uri}-metadata.json"
  			missing_files << URI.join(action_uri, 'csv-metadata.json').to_s
		end
		entry["implicit"].each do |implicit|
			implicit_uri, implicit_file = cache_file(implicit)
			provided_files << implicit_uri.to_s
			unless implicit_uri == metadata
				file.puts "\t\tAnd I have a file called \"csvw/#{implicit}\" at the url \"#{implicit_uri}\""
			end
		end if entry["implicit"]
		missing_files.each do |uri|
			file.puts "\t\tAnd there is no file at the url \"#{uri}\"" unless provided_files.include? uri
		end
		file.puts "\t\tWhen I transform the CSV into RDF#{entry["option"] && entry["option"]["minimal"] ? " in minimal mode" : ""}"
		if entry["type"] == "csvt:ToRdfTestWithWarnings"
			file.puts "\t\tThen there should not be errors"
			file.puts "\t\tAnd there should be warnings"
		elsif entry["type"] == "csvt:NegativeRdfTest"
	    	file.puts "\t\tThen there should be errors"
		else
		    file.puts "\t\tThen there should not be errors"
		    file.puts "\t\tAnd there should not be warnings"
		end
		if entry["result"]
			result_uri, result_file = cache_file(entry["result"])
			file.puts "\t\tAnd the RDF should match that in \"csvw/#{entry["result"]}\""
		end
		file.puts "\t"
	end
end unless File.exist? RDF_TRANSFORMATION_FEATURE_FILE_PATH
