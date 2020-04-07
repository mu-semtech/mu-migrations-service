# mu-migrations-service

The mu-migrations-service runs migrations on the database.  This
currently includes SPARQL queries (`*.sparql`) and Turtle files (`*.ttl`).
We intend more formats to be supported in the future.

Migrations are run sequentially in alphabetical order of the file name. A migration has to complete successfully in order for the next migration to start, there is no concurrent execution of migrations. If a migration fails to run, no subsequent migrations will be attempted.

The completion of a migration is stored in the database. A migration that has been marked as completed will not be started again.

## How to

Migrations are specified in files, to be executed in the order of
their filename. The files may reside in subfolders. It is advised
to use the unix system time as the basis for the filename of your
migration, postfixed with a short name of what the migration performs.

### Specifying the migration

#### SPARQL queries
Specify the migration in a file, like
`./config/migrations/20160808225103-statuses.sparql` containing a SPARQL
query like:

```
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX tac: <http://tasks-at-hand.com/vocabularies/core/>
    PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
    PREFIX rm: <http://mu.semte.ch/vocabularies/logical-delete/>
    PREFIX typedLiterals: <http://mu.semte.ch/vocabularies/typed-literals/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
    PREFIX app: <http://mu.semte.ch/app/>
    PREFIX owl: <http://www.w3.org/2002/07/owl#>
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    INSERT DATA {
      GRAPH <http://mu.semte.ch/application> {
        <http://tasks-at-hand.com/resources/statuses/not_started>
          a tac:Status;
          mu:uuid "wellknown-status-not_started";
          dct:title "not started".
        <http://tasks-at-hand.com/resources/statuses/ongoing>
          a tac:Status;
          mu:uuid "wellknown-status-ongoing";
          dct:title "ongoing".
        <http://tasks-at-hand.com/resources/statuses/done>
          a tac:Status;
          mu:uuid "wellknown-status-done";
          dct:title "done".
      }
    }
```

#### Turtle files
Specify the migration in a file, like
`./config/migrations/20160808225103-statuses.ttl` containing triples in Turtle format like:

```
    @prefix dct: <http://purl.org/dc/terms/> .
    @prefix tac: <http://tasks-at-hand.com/vocabularies/core/> .
    @prefix ext: <http://mu.semte.ch/vocabularies/ext/> .
    @prefix rm: <http://mu.semte.ch/vocabularies/logical-delete/> .
    @prefix typedLiterals: <http://mu.semte.ch/vocabularies/typed-literals/> .
    @prefix mu: <http://mu.semte.ch/vocabularies/core/> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    @prefix app: <http://mu.semte.ch/app/> .
    @prefix owl: <http://www.w3.org/2002/07/owl#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

    <http://tasks-at-hand.com/resources/statuses/not_started>
          a tac:Status;
          mu:uuid "wellknown-status-not_started";
          dct:title "not started".
    <http://tasks-at-hand.com/resources/statuses/ongoing>
          a tac:Status;
          mu:uuid "wellknown-status-ongoing";
          dct:title "ongoing".
    <http://tasks-at-hand.com/resources/statuses/done>
          a tac:Status;
          mu:uuid "wellknown-status-done";
          dct:title "done".
```

By default, the Turtle files will be imported in the `<http://mu.semte.ch/application>` graph.

#### Graphs
This feature is experimental. In case a `.graph`-file by the same name as a `.ttl`-file is present, the triples in the `.ttl`-file will be imported into the graph specified in its corresponding `.graph`-file, in the same fashion as [OpenLink Virtuoso](http://docs.openlinksw.com/virtuoso/rdfperfloading/#rdfperfloadingutility) does. The content of a `.graph`-file such as `./config/migrations/20160808225103-statuses.graph` may look like this:

```
http://mu.semte.ch/custom-graph
```


### Sharing the migration with the service

Run the migrations service in your pipeline, add the
migrations-service to your mu-project and make sure all migrations are
available in `/data/migrations`. The migrations may be grouped in subfolders.

```
    migrationsservice:
      image: semtech/mu-migrations-service
      links:
        - db:database
      volumes:
        - ./config/migrations:/data/migrations
```

The migration will be ran when the mu-migrations-service starts up,
and output about the status of the ran migrations will be written to
the database for later inspection.

## Configuration

The migration service supports configuration via environment variables.

### Large datasets and batch size
Triple stores typically can only handle a certain amount of triples to be ingested per request. The migration service supports batching to split of large datasets in multiple requests. This can be configured with the `BATCH_SIZE` environment variable. If an error occurs during batch ingestion the batch size will be halved and the request retried until `MINIMUM_BATCH_SIZE` is reached. At this point an error will be thrown. 

To make sure a dataset is loaded completely it will first be ingested into a temporary graph, on success the contents will be added to the target graph with a SPARQL Graph query. 


- `BATCH_SIZE`: amount of triples to insert in one go (default: 12000)
- `MINIMUM_BATCH_SIZE`: if the batch size drops below this number the service will stop with an error. (default: 100)

### General configuration
This microservice is based on the [mu-ruby template](https://github.com/mu-semtech/mu-ruby-template) and supports the environment variables documented in its [README](https://github.com/mu-semtech/mu-ruby-template#configuration).
