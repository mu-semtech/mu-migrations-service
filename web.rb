require 'net/http'

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
    # TODO log.info "Executing migration #{filename}"
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

def execute_migrations
  endpoint = Proc.new { |q| SinatraTemplate::Helpers.query q }
  locations = Dir.glob('/data/migrations/*.sparql')
  migrations = locations.map { |location| Migration.new location, endpoint }
  migrations.sort! do |a,b|
    # I'm assuming no numbers will be in the path, this may be wrong
    a.order <=> b.order
  end

  puts "There are #{migrations.length} migrations defined"

  migrations.each do |migration|
    migration.execute! unless migration.executed?
  end
  puts "All migrations executed"
end

def is_database_up?
  begin
    location = URI('http://database:8890/sparql')
    response = Net::HTTP.get_response( location )
    return response.is_a? Net::HTTPSuccess
  rescue Errno::ECONNREFUSED
    return false
  end
end

def wait_for_database
  until is_database_up?
    puts "Waiting for database... "
    sleep 2
  end

  puts "Database is up"
end

def boot
  wait_for_database
  execute_migrations
end

boot
