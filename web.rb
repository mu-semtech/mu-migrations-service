require 'net/http'
require 'securerandom'

MU_MIGRATIONS = RDF::Vocabulary.new('http://mu.semte.ch/vocabularies/migrations/')

# see https://github.com/mu-semtech/mu-ruby-template for more info
class Migration

  include SinatraTemplate::Utils

  def initialize( location )
    @location = location
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
    @content ||= File.open(self.location, 'r:UTF-8').read
  end

  def executed?
    @executed ||= query(
      "ASK { " +
      "  GRAPH <#{graph}> { " +
      "    ?migration a <#{MU_MIGRATIONS.Migration}>;" +
      "               <#{MU_MIGRATIONS.filename}> #{filename.sparql_escape}." +
      "  }" +
      " }")
  end

  def execute!
    log.info "Executing migration #{filename}"
    @executed = true

    if filename.end_with? ".sparql"
      log.debug "Executing the migration query"
      query(self.content)
    elsif filename.end_with? ".ttl"
      log.debug "Importing the migration file"
      data = RDF::Graph.load(self.location, format: :ttl)
      batch_insert(data, graph: graph)
    else
      log.warn "Unsupported file format #{filename}"
    end

    log.debug "Registering the migration"
    update "INSERT DATA {" +
                  "  GRAPH <#{graph}> { " +
                  "    <#{self.uri}> a <#{MU_MIGRATIONS.Migration}>;" +
                  "                  <#{MU_MIGRATIONS.filename}> #{filename.sparql_escape};" +
                  "                  <#{MU_MIGRATIONS.executedAt}> #{DateTime.now.sparql_escape}." +
                  "  }" +
                  "}"
  end

  def to_s
    "#{self.location} #{if executed? then "[DONE]" else "[NOT EXECUTED]" end}"
  end

  private
  def batch_insert(data, graph:, batch_size: 3000)
    log.info("dataset of #{data.size} triples will be inserted in batches of #{batch_size} triples")
    temp_graph = "http://migrations.mu.semte.ch/#{SecureRandom.uuid}"
    begin
      data.each_slice(batch_size) do |slice|
        sparql_client.insert_data(slice, graph: temp_graph)
      end
      update("ADD <#{temp_graph}> TO <#{graph}>")
    rescue => e
      log.error("error batch loading triples, batch_size #{batch_size}")
      raise e
    ensure
      update("DROP SILENT GRAPH <#{temp_graph}>")
    end
  end
end

def execute_migrations
  locations = Dir.glob('/data/migrations/**/*.sparql')
  locations += Dir.glob('/data/migrations/**/*.ttl')

  migrations = locations.map { |location| Migration.new location }
  migrations.sort! do |a,b|
    # I'm assuming no numbers will be in the path, this may be wrong
    a.order <=> b.order
  end

  log.info "There are #{migrations.length} migrations defined"

  summary = "\n\nMIGRATIONS STATUS\n"
  summary << "-----------------\n"
  migrations.each do |migration|
    migration.execute! unless migration.executed?
    summary << "#{migration}\n"
  end
  log.info "All migrations executed"
  log.info summary
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
