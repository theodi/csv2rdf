require 'csvlint'
require 'rdf'

module Csvlint
  module Csvw
    class Csv2Rdf

      include Csvlint::ErrorCollector

      attr_reader :result, :minimal, :validate

      def initialize(source, dialect = {}, schema = nil, options = {})
        reset
        @source = source
        @result = RDF::Graph.new
        @minimal = options[:minimal] || false
        @validate = options[:validate] || false

        if schema.nil?
          @table_group = RDF::Node.new
          @result << [ @table_group, RDF.type, CSVW.TableGroup ] unless @minimal

          @rownum = 0
          @columns = []

          @validator = Csvlint::Validator.new( @source, dialect, schema, { :validate => @validate, :lambda => lambda { |v| transform(v) } } )
          @errors += @validator.errors
          @warnings += @validator.warnings
        else
          @table_group = RDF::Node.new
          @result << [ @table_group, RDF.type, CSVW.TableGroup ] unless @minimal

          schema.tables.each do |table_url, table|
            @source = table_url

            @rownum = 0
            @columns = []

            @validator = Csvlint::Validator.new( @source, dialect, schema, { :validate => @validate, :lambda => table.suppress_output ? lambda { |a| nil } : lambda { |v| transform(v) } } )
            @warnings += @validator.errors
            @warnings += @validator.warnings
          end
        end
      end

      private
        def transform(v)
          if v.data[-1]
            if @columns.empty?
              initialize_result(v)
            end
            if v.current_line > v.dialect["headerRowCount"]
              @rownum += 1
              @row = RDF::Node.new
              row_data = transform_data(v.data[-1], v.current_line)
              unless @minimal
                @result << [ @table, CSVW.row, @row ]
                @result << [ @row, RDF.type, CSVW.Row ]
                @result << [ @row, CSVW.rownum, @rownum ]
                @result << [ @row, CSVW.url, RDF::Resource.new("#{@source}#row=#{v.current_line}") ]
                row_data.each do |r|
                  @result << [ @row, CSVW.describes, r ]
                end
              end
            end
          else
            build_errors(:blank_rows, :structure)
          end
        end

        def initialize_result(v)
          unless v.errors.empty?
            @errors += v.errors
          end
          @row_title_columns = []
          if v.schema.nil?
            v.data[0].each_with_index do |h,i|
              @columns.push Csvlint::Csvw::Column.new(i+1, h)
            end
            @table = RDF::Node.new
            unless @minimal
              @result << [ @table_group, CSVW.table, @table ]
              @result << [ @table, RDF.type, CSVW.Table ]
              @result << [ @table, CSVW.url, RDF::Resource.new(@source) ]
            end
          else
            table = v.schema.tables[@source]
            @table = table.id ? RDF::Resource.new(table.id) : RDF::Node.new

            unless @minimal
              v.schema.annotations.each do |a,v|
                transform_annotation(@table_group, a, v)
              end
              unless table.suppress_output
                @result << [ @table_group, CSVW.table, @table ]
                @result << [ @table, RDF.type, CSVW.Table ]
                @result << [ @table, CSVW.url, RDF::Resource.new(@source) ]
                table.annotations.each do |a,v|
                  transform_annotation(@table, a, v)
                end
                transform_annotation(@table, CSVW.note, table.notes) unless table.notes.empty?
              end
            end

            if table.columns.empty?
              v.data[0].each_with_index do |h,i|
                @columns.push Csvlint::Csvw::Column.new(i+1, "_col.#{i+1}")
              end
            else
              @columns = table.columns.clone
              remainder = v.data[0][table.columns.length..-1]
              remainder.each_with_index do |h,i|
                @columns.push Csvlint::Csvw::Column.new(i+1, "_col.#{table.columns.length+i+1}")
              end if remainder
            end
            table.row_title_columns.each do |c|
              @row_title_columns << (c.name || c.default_name)
            end if table.row_title_columns
          end
          # @result["tables"][-1]["row"] = []
        end

        def transform_data(data, sourceRow)
          values = {}
          @columns.each_with_index do |column,i|
            unless data[i].nil?
              column_name = column.name || column.default_name
              base_type = column.datatype["base"] || column.datatype["@id"]
              datatype = column.datatype["@id"] || base_type
              if data[i].is_a? Array
                v = []
                data[i].each do |d|
                  v << Csv2Rdf.value_to_rdf(d, datatype, base_type, column.lang)
                end
              else
                v = Csv2Rdf.value_to_rdf(data[i], datatype, base_type, column.lang)
              end
              values[column_name] = v
            end
          end
          values["_row"] = @rownum
          values["_sourceRow"] = sourceRow

          @row_title_columns.each do |column_name|
            @result << [ @row, CSVW.title, values[column_name] ]
          end unless @minimal

          row_subject = RDF::Node.new
          subjects = []
          @columns.each_with_index do |column,i|
            unless column.suppress_output
              column_name = column.name || column.default_name
              values["_column"] = i
              values["_sourceColumn"] = i
              values["_name"] = column_name

              subject = column.about_url ? RDF::Resource.new(URI.join(@source, column.about_url.expand(values)).to_s) : row_subject
              subjects << subject
              property = property(column, values)

              if column.value_url
                value = value(column, values, property == "@type")
              else
                value = values[column_name]
              end

              unless value.nil?
                if column.separator && column.ordered
                  list = RDF::List[]
                  list[0..Array(value).length] = Array(value)
                  @result << [ subject, property, list.subject ]
                  list.each_statement do |s|
                    @result << s
                  end
                else
                  Array(value).each do |v|
                    @result << [ subject, property, v ]
                  end
                end
              end
            end
          end

          return subjects.uniq
        end

        def transform_annotation(subject, property, value)
          property = RDF::Resource.new(Csv2Rdf.expand_prefixes(property)) unless property.is_a? RDF::Resource
          case value
          when Hash
            if value["@id"]
              @result << [ subject, property, RDF::Resource.new(value["@id"]) ]
            elsif value["@value"]
              if value["@type"]
                @result << [ subject, property, RDF::Literal.new(value["@value"], :datatype => Csv2Rdf.expand_prefixes(value["@type"])) ]
              else
                @result << [ subject, property, RDF::Literal.new(value["@value"], :language => value["@language"]) ]
              end
            else
              object = RDF::Node.new
              @result << [ subject, property, object ]
              value.each do |a,v|
                if a == "@type"
                  @result << [ object, RDF.type, RDF::Resource.new(Csv2Rdf.expand_prefixes(v)) ]
                else
                  transform_annotation(object, a, v)
                end
              end
            end
          when Array
            value.each do |v|
              transform_annotation(subject, property, v)
            end
          else
            @result << [ subject, property, value ]
          end 
        end

        def property(column, values)
          if column.property_url
            url = column.property_url.expand(values)
            url = Csv2Rdf.expand_prefixes(url)
            url = URI.join(@source, url)
          else
            url = column.name || column.default_name || "_col.#{column.number}"
            url = URI.join(@source, "##{URI.escape(url, Regexp.new("[^A-Za-z0-9_.]"))}")
          end
          return RDF::Resource.new(url)
        end

        def value(column, values, compact)
          if values[column.name || column.default_name].nil? && !column.virtual
            return nil
          else
            url = column.value_url.expand(values)
            url = Csv2Rdf.expand_prefixes(url) unless compact
            url = URI.join(@source, url)
            return RDF::Resource.new(url)
          end
        end

        def Csv2Rdf.value_to_rdf(value, datatype, base_type, lang)
          return value[:invalid] if value.is_a? Hash and value[:invalid]
          if value.is_a? Float
            if value.nan?
              return RDF::Literal.new("NaN", :datatype => datatype)
            elsif value == Float::INFINITY
              return RDF::Literal.new("INF", :datatype => datatype)
            elsif value == -Float::INFINITY
              return RDF::Literal.new("-INF", :datatype => datatype)
            else
              return RDF::Literal.new(value, :datatype => datatype)
            end
          elsif NUMERIC_DATATYPES.include? base_type
            return RDF::Literal.new(value, :datatype => datatype)
          elsif base_type == "http://www.w3.org/2001/XMLSchema#boolean"
            return value
          elsif DATETIME_DATATYPES.include? base_type
            return RDF::Literal.new(value[:string], :datatype => datatype)
          elsif base_type == "http://www.w3.org/2001/XMLSchema#string"
            return RDF::Literal.new(value.to_s, :datatype => datatype) if datatype != base_type
            return RDF::Literal.new(value.to_s, :language => lang == "und" ? nil : lang)
          else
            return RDF::Literal.new(value.to_s, :datatype => datatype)
          end
        end

        def Csv2Rdf.expand_prefixes(url)
          return "http://www.w3.org/ns/csvw##{url}" if TERMS.include?(url)
          NAMESPACES.each do |prefix,ns|
            url = url.gsub(Regexp.new("^#{Regexp.escape(prefix)}:"), "#{ns}")
          end
          return url
        end

        CSVW = RDF::Vocabulary.new("http://www.w3.org/ns/csvw#")

        NAMESPACES = {
          "dcat" => "http://www.w3.org/ns/dcat#",
          "qb" => "http://purl.org/linked-data/cube#",
          "grddl" => "http://www.w3.org/2003/g/data-view#",
          "ma" => "http://www.w3.org/ns/ma-ont#",
          "org" => "http://www.w3.org/ns/org#",
          "owl" => "http://www.w3.org/2002/07/owl#",
          "prov" => "http://www.w3.org/ns/prov#",
          "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
          "rdfa" => "http://www.w3.org/ns/rdfa#",
          "rdfs" => "http://www.w3.org/2000/01/rdf-schema#",
          "rif" => "http://www.w3.org/2007/rif#",
          "rr" => "http://www.w3.org/ns/r2rml#",
          "sd" => "http://www.w3.org/ns/sparql-service-description#",
          "skos" => "http://www.w3.org/2004/02/skos/core#",
          "skosxl" => "http://www.w3.org/2008/05/skos-xl#",
          "wdr" => "http://www.w3.org/2007/05/powder#",
          "void" => "http://rdfs.org/ns/void#",
          "wdrs" => "http://www.w3.org/2007/05/powder-s#",
          "xhv" => "http://www.w3.org/1999/xhtml/vocab#",
          "xml" => "http://www.w3.org/XML/1998/namespace",
          "xsd" => "http://www.w3.org/2001/XMLSchema#",
          "csvw" => "http://www.w3.org/ns/csvw#",
          "cnt" => "http://www.w3.org/2008/content",
          "earl" => "http://www.w3.org/ns/earl#",
          "ht" => "http://www.w3.org/2006/http#",
          "oa" => "http://www.w3.org/ns/oa#",
          "ptr" => "http://www.w3.org/2009/pointers#",
          "cc" => "http://creativecommons.org/ns#",
          "ctag" => "http://commontag.org/ns#",
          "dc" => "http://purl.org/dc/terms/",
          "dcterms" => "http://purl.org/dc/terms/",
          "dc11" => "http://purl.org/dc/elements/1.1/",
          "foaf" => "http://xmlns.com/foaf/0.1/",
          "gr" => "http://purl.org/goodrelations/v1#",
          "ical" => "http://www.w3.org/2002/12/cal/icaltzd#",
          "og" => "http://ogp.me/ns#",
          "rev" => "http://purl.org/stuff/rev#",
          "sioc" => "http://rdfs.org/sioc/ns#",
          "v" => "http://rdf.data-vocabulary.org/#",
          "vcard" => "http://www.w3.org/2006/vcard/ns#",
          "schema" => "http://schema.org/"
        }

        TERMS = 
          NAMESPACES.keys +
          [ "TableGroup", "Table", "Column", "Row", "Cell", "Schema", "Datatype", "Dialect", "Direction", "ForeignKey", "NumericFormat", "TableReference", "Transformation" ]

        NUMERIC_DATATYPES = [
          "http://www.w3.org/2001/XMLSchema#decimal",
          "http://www.w3.org/2001/XMLSchema#integer",
          "http://www.w3.org/2001/XMLSchema#long",
          "http://www.w3.org/2001/XMLSchema#int",
          "http://www.w3.org/2001/XMLSchema#short",
          "http://www.w3.org/2001/XMLSchema#byte",
          "http://www.w3.org/2001/XMLSchema#nonNegativeInteger",
          "http://www.w3.org/2001/XMLSchema#positiveInteger",
          "http://www.w3.org/2001/XMLSchema#unsignedLong",
          "http://www.w3.org/2001/XMLSchema#unsignedInt",
          "http://www.w3.org/2001/XMLSchema#unsignedShort",
          "http://www.w3.org/2001/XMLSchema#unsignedByte",
          "http://www.w3.org/2001/XMLSchema#nonPositiveInteger",
          "http://www.w3.org/2001/XMLSchema#negativeInteger",
          "http://www.w3.org/2001/XMLSchema#double",
          "http://www.w3.org/2001/XMLSchema#float"
        ]

        DATETIME_DATATYPES = [
          "http://www.w3.org/2001/XMLSchema#date",
          "http://www.w3.org/2001/XMLSchema#dateTime",
          "http://www.w3.org/2001/XMLSchema#dateTimeStamp",
          "http://www.w3.org/2001/XMLSchema#time",
          "http://www.w3.org/2001/XMLSchema#gYear",
          "http://www.w3.org/2001/XMLSchema#gYearMonth",
          "http://www.w3.org/2001/XMLSchema#gMonth",
          "http://www.w3.org/2001/XMLSchema#gMonthDay",
          "http://www.w3.org/2001/XMLSchema#gDay",
        ]

    end
  end
end
