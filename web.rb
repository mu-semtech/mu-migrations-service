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

  def executed?(*args)
    if @executed.nil?
      if args.size >= 1
        executed_migrations = args[0]
        @executed = executed_migrations.include?(self.filename)
      else
        @executed = query(
          "ASK { " +
          "  GRAPH <#{graph}> { " +
          "    ?migration a <#{MU_MIGRATIONS.Migration}>;" +
          "               <#{MU_MIGRATIONS.filename}> #{filename.sparql_escape}." +
          "  }" +
          " }")
      end
    end

    @executed
  end

  def execute!
    log.info "Executing migration #{filename}"
    @executed = true

    if filename.end_with? ".sparql"
      log.debug "Executing the migration query"
      query(self.content)
    elsif filename.end_with? ".ttl"
      data = RDF::Graph.load(self.location, format: :ttl)
      if File.exists?(self.location.gsub(".ttl",".graph"))
        File.open(self.location.gsub(".ttl",".graph")) do |file|
          first_line = file.readlines.first.strip
          log.debug "Importing the migration file into #{first_line}"
          batch_insert(data, graph: first_line)
        end
      else
        log.debug "Importing the migration file into #{graph}"
        batch_insert(data, graph: graph)
      end
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
  def batch_insert(data, graph:, batch_size: ENV['BATCH_SIZE'].to_i)
    log.info("dataset of #{data.size} triples will be inserted in batches of #{batch_size} triples")
    temp_graph = "http://migrations.mu.semte.ch/#{SecureRandom.uuid}"
    from = 0
    data = data.to_a
    begin
      while from < data.size do
        slice = data.slice(from, batch_size)
        log.info("inserting triples #{from} to #{[from + batch_size, data.size].min}")
        begin
          sparql_client.insert_data(slice, graph: temp_graph)
          from = from + batch_size
        rescue => e
          log.warn "error loading triples (#{e.message}), retrying with a smaller batch size"
          batch_size = batch_size / 2
          if batch_size < ENV['MINIMUM_BATCH_SIZE'].to_i
            log.error "batch size has dropped below 100, no longer retrying"
            raise e
          end
        end
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
  executed_migrations = fetch_executed_migrations

  locations = Dir.glob('/data/migrations/**/*.sparql')
  locations += Dir.glob('/data/migrations/**/*.ttl')

  migrations = locations.map { |location| Migration.new location }
  migrations.sort! do |a,b|
    # I'm assuming no numbers will be in the path, this may be wrong
    a.order <=> b.order
  end

  summary = "\n\nMIGRATIONS STATUS\n"
  summary << "-----------------\n"
  count = 0
  migrations.each do |migration|
    unless migration.executed? executed_migrations
      migration.execute!
      count += 1
    end
    summary << "#{migration}\n"
  end
  log.info "#{count} migrations executed now"
  log.info "All migrations executed"
  log.info summary
end

def fetch_executed_migrations
  log.info("Fetching already executed migrations")
  count_result = query("SELECT (COUNT(DISTINCT ?migration) as ?count) WHERE { " +
                       "  GRAPH <#{graph}> { " +
                       "    ?migration a <#{MU_MIGRATIONS.Migration}> ." +
                       "  }" +
                       " }")
  total = if count_result.count > 0 then count_result.first[:count].value.to_i else 0 end

  batch_size = ENV['COUNT_BATCH_SIZE'].to_i
  executed_migrations = []
  from = 0
  while from < total do
    solutions = query("SELECT DISTINCT ?migration ?filename WHERE { " +
                      "  GRAPH <#{graph}> { " +
                      "    ?migration a <#{MU_MIGRATIONS.Migration}> ;" +
                      "               <#{MU_MIGRATIONS.filename}> ?filename ." +
                      "  }" +
                      " } LIMIT #{batch_size} OFFSET #{from}")
    executed_migrations += solutions.map { |solution| solution.filename.value }
    from = from + batch_size
  end

  log.info "#{total} migrations already executed before"
  executed_migrations
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
