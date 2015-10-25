require 'coveralls'
Coveralls.wear_merged!('test_frameworks')

$:.unshift File.join( File.dirname(__FILE__), "..", "..", "lib")

require 'rspec/expectations'
require 'cucumber/rspec/doubles'
require 'csvlint/csvw/csv2rdf'
require 'rdf/turtle'
require 'rdf/isomorphic'
require 'pry'

module RDF
  module Isomorphic
    alias_method :==, :isomorphic_with?
  end
end

require 'spork'

Spork.each_run do
  require 'csvlint/csvw/csv2rdf'
end

class CustomWorld
  def default_csv_options
    return {
    }
  end
end

World do
  CustomWorld.new
end
