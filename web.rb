MU_MIGRATIONS = RDF::Vocabulary.new('http://mu.semte.ch/vocabularies/migrations/')

# see https://github.com/mu-semtech/mu-ruby-template for more info
class Migration
  def initialize( location, endpoint )
    @location = location
    @endpoint = endpoint
  end

  def uri
    # should escape the location for erroneous symbols, like < and >
    "file://#{self.location}"
  end

  def location
    @location
  end

  def order
    # I'm assuming no numbers will be in the path.
    # This is correct in the current setup of our
    # container, but might not be the best approach.
    @number ||= /\d+/.match(self.filename).to_s.to_i
  end

  def filename
    @location.split('/').last
  end

  def content
    @content ||= File.open(self.location).read
  end

  def executed?
    @executed ||= @endpoint.call(
      "ASK { " +
      "  GRAPH <#{Sinatra::Application.settings.graph}> { " +
      "    ?migration a <#{MU_MIGRATIONS.migration}>;" +
      "               <#{MU_MIGRATIONS.filename}> #{filename.sparql_escape}." +
      "  }" +
      " }")
  end

  def execute!
    @executed = true
    # Execute the update
    @endpoint.call(self.content)
    # Register the migration
    @endpoint.call "INSERT DATA {" +
                  "  GRAPH <#{Sinatra::Application.settings.graph}> { " +
                  "    <#{self.uri}> a <#{MU_MIGRATIONS.migration}>;" +
                  "                  <#{MU_MIGRATIONS.filename}> #{filename.sparql_escape}." +
                  "  }" +
                  "}"
  end

  def to_s
    "#{self.location} #{if executed? then "V" else "X" end}"
  end
end

get '/' do
  content_type 'application/json'
  endpoint = Proc.new { |q| query q }
  locations = Dir.glob('/data/migrations/*.sparql')
  migrations = locations.map { |location| Migration.new location, endpoint }
  migrations.sort! do |a,b|
    # I'm assuming no numbers will be in the path, this may be wrong
    a.order <=> b.order
  end

  migrations.each do |migration|
    migration.execute! unless migration.executed?
  end

  {
    data: {
      attributes: { hello: 'world' },
      migrations: migrations
    }
  }.to_json
end
