require 'net/http'

MU_MIGRATIONS = RDF::Vocabulary.new('http://mu.semte.ch/vocabularies/migrations/')

# see https://github.com/mu-semtech/mu-ruby-template for more info
class Migration

  include SinatraTemplate::Utils

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
      "  GRAPH <#{graph}> { " +
      "    ?migration a <#{MU_MIGRATIONS.migration}>;" +
      "               <#{MU_MIGRATIONS.filename}> #{filename.sparql_escape}." +
      "  }" +
      " }")
  end

  def execute!
    log.info "Executing migration #{filename}"
    @executed = true
    log.debug "Executing the migration query"
    @endpoint.call(self.content)
    log.debug "Registering the migration"
    @endpoint.call "INSERT DATA {" +
                  "  GRAPH <#{graph}> { " +
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
  endpoint = Proc.new { |q| SinatraTemplate::Utils.query q }
  locations = Dir.glob('/data/migrations/**/*.sparql')
  migrations = locations.map { |location| Migration.new location, endpoint }
  migrations.sort! do |a,b|
    # I'm assuming no numbers will be in the path, this may be wrong
    a.order <=> b.order
  end

  log.info "There are #{migrations.length} migrations defined"

  migrations.each do |migration|
    migration.execute! unless migration.executed?
  end
  log.info "All migrations executed"
end

def is_database_up?
  begin
    location = URI(ENV['MU_SPARQL_ENDPOINT'])
    response = Net::HTTP.get_response( location )
    return response.is_a? Net::HTTPSuccess
  rescue Errno::ECONNREFUSED
    return false
  end
end

def wait_for_database
  until is_database_up?
    log.info "Waiting for database... "
    sleep 2
  end

  log.info "Database is up"
end

def boot
  wait_for_database
  execute_migrations
end

boot
