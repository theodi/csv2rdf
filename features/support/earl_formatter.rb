require 'rdf'
require 'rdf/turtle'

class EarlFormatter
  def initialize(step_mother, io, options)
    output = RDF::Resource.new("")
    @graph = RDF::Graph.new
    @graph << [ CSV2RDF, RDF.type, RDF::DOAP.Project ]
    @graph << [ CSV2RDF, RDF.type, EARL.TestSubject ]
    @graph << [ CSV2RDF, RDF.type, EARL.Software ]
    @graph << [ CSV2RDF, RDF::DOAP.name, "csv2rdf" ]
    @graph << [ CSV2RDF, RDF::DC.title, "csv2rdf" ]
    @graph << [ CSV2RDF, RDF::DOAP.homepage, RDF::Resource.new("https://github.com/theodi/csvlint.rb") ]
    @graph << [ CSV2RDF, RDF::DOAP.license, RDF::Resource.new("https://raw.githubusercontent.com/theodi/csvlint.rb/master/LICENSE.md") ]
    @graph << [ CSV2RDF, RDF::DOAP["programming-language"], "Ruby" ]
    @graph << [ CSV2RDF, RDF::DOAP.implements, RDF::Resource.new("http://www.w3.org/TR/tabular-data-model/") ]
    @graph << [ CSV2RDF, RDF::DOAP.implements, RDF::Resource.new("http://www.w3.org/TR/tabular-metadata/") ]
    @graph << [ CSV2RDF, RDF::DOAP.implements, RDF::Resource.new("http://www.w3.org/TR/csv2rdf/") ]
    @graph << [ CSV2RDF, RDF::DOAP.developer, ODI ]
    @graph << [ CSV2RDF, RDF::DOAP.maintainer, ODI ]
    @graph << [ CSV2RDF, RDF::DOAP.documenter, ODI ]
    @graph << [ CSV2RDF, RDF::FOAF.maker, ODI ]
    @graph << [ CSV2RDF, RDF::DC.creator, ODI ]
    @graph << [ CSV2RDF, RDF::DC["isPartOf"], CSVLINT ]
    @graph << [ output, RDF::FOAF["primaryTopic"], CSV2RDF ]
    @graph << [ output, RDF::DC.issued, DateTime.now ]
    @graph << [ output, RDF::FOAF.maker, ODI ]
    @graph << [ ODI, RDF.type, RDF::FOAF.Organization ]
    @graph << [ ODI, RDF.type, EARL.Assertor ]
    @graph << [ ODI, RDF::FOAF.name, "Open Data Institute" ]
    @graph << [ ODI, RDF::FOAF.homepage, "https://theodi.org/" ]
  end

  def scenario_name(keyword, name, file_colon_line, source_indent)
    @test = RDF::Resource.new("http://www.w3.org/2013/csvw/tests/#{name.split(" ")[0]}")
  end

  def after_steps(steps)
    passed = true
    steps.each do |s|
      passed = false unless s.status == :passed
    end
    a = RDF::Node.new
    @graph << [ a, RDF.type, EARL.Assertion ]
    @graph << [ a, EARL.assertedBy, ODI ]
    @graph << [ a, EARL.subject, CSV2RDF ]
    @graph << [ a, EARL.test, @test ]
    @graph << [ a, EARL.mode, EARL.automatic ]
    r = RDF::Node.new
    @graph << [ a, EARL.result, r ]
    @graph << [ r, RDF.type, EARL.TestResult ]
    @graph << [ r, EARL.outcome, passed ? EARL.passed : EARL.failed ]
    @graph << [ r, RDF::DC.date, DateTime.now ]
  end

  def after_features(features)
    RDF::Writer.for(:ttl).open("csv2rdf-earl.ttl", { :prefixes => { "earl" => EARL }, :standard_prefixes => true, :canonicalize => true, :literal_shorthand => true }) do |writer|
      writer << @graph
    end 
  end

  private
    EARL = RDF::Vocabulary.new("http://www.w3.org/ns/earl#")
    ODI = RDF::Resource.new("https://theodi.org/")
    CSV2RDF = RDF::Resource.new("https://github.com/theodi/csv2rdf")
    CSVLINT = RDF::Resource.new("https://github.com/theodi/csvlint.rb")

end
