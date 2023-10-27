# mu-migrations-service

The mu-migrations-service runs migrations on the database.  This currently includes SPARQL queries (`*.sparql`) and Turtle files (`*.ttl`). We intend more formats to be supported in the future.

## Tutorials

### Add the migrations service to a stack
To install the migrations service in your project, add the migrations-service to
the `docker-compose.yml` file of your mu-project by adding the following snippet:

```
    migrations:
      image: semtech/mu-migrations-service:0.9.0
      links:
        - triplestore:database
      volumes:
        - ./config/migrations:/data/migrations
```

`triplestore` is the service name of the database (probably a Virtuoso instance) running in your stack.

Start your stack using `docker-compose up -d`. The migrations service will be created.

Execute `docker-compose logs -ft migrations` to inspect the logs of the service. You will see the migrations service started up successfully. No migrations are executed since we didn't define one yet. Let's go to the next step and create our first migration!


### Writing a migration to update a predicate in your dataset
We're going to define a migration that will change all predicates `schema:name` in our dataset to `foaf:name`.

First, create a new migration file `./config/migrations/20200329140538-replace-schema-name-with-foaf-name.sparql`.
Next, insert the SPARQL query to execute the change in the file.

```
    PREFIX schema: <http://schema.org/>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>

    DELETE {
      GRAPH ?g { ?s schema:name ?o . }
    } INSERT {
      GRAPH ?g { ?s foaf:name ?o . }
    } WHERE {
      GRAPH ?g { ?s schema:name ?o . }
    }
```

Restart the migrations service by running `docker-compose restart migrations`. Inspect the logs using `docker-compose logs -ft migrations`. You will see the migration gets executed and the success status is printed in the migrations summary in the logs.

## How-to guides

### Manipulating data using a SPARQL query

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

### Inserting data in the default graph using Turtle files
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

### Inserting data in a specific graph using Turtle files (experimental)
To insert data in a specific graph instead of the default graph, create a `.graph`-file by the same name as the `.ttl`-file. E.g. `./config/migrations/20160808225103-statuses.graph` for a Turtle migration named `./config/migrations/20160808225103-statuses.ttl`.

The `.graph` file contains only one line, specifying the graph name to insert the data in:

```
http://mu.semte.ch/graphs/custom-graph
```

## Reference
### Naming and organizing the migrations
Migrations are specified in files, to be executed in the order of their filename. All the files need to be available in `/data/migrations` inside the docker container, but the may be organized in subfolders.

The name of a migration file must always start with a number and be unique across all migrations (also migrations stored in other folders!).
It is advised to use the unix system time as the basis for the filename of your migration, postfixed with a short name of what the migration performs. E.g. `20200329140538-replace-schema-name-with-foaf-name.sparql`.

Since the execution state of a migration is determined only be the filename and not the full file path, subfolders may be reorganized after execution of a migration. This allows for example to archive migrations in subfolders per year while the project progresses.

### Execution guarantees
The migrations service provides the following guarantees of execution:
- Migrations are run sequentially in order of the first number in the filename, in ascending order.
- A migration has to complete successfully in order for the next migration to start, there is no concurrent execution of migrations.
- If a migration fails to run, no subsequent migrations will be attempted.
- A migration that has been marked as completed will not be started again nor will a migration with the same filename be executed.

### Migration management in the database
The completion of a migration is stored in the database in the `MU_APPLICATION_GRAPH` (default: `<http://mu.semte.ch/application>`).

Each successfully executed migration is represented by a resource of type `muMigr:Migration` with the following properties:
- `muMigr:filename`: name of the migration file
- `muMigr:executedAt`: datetime when the migration successfully finished

Used prefix: `muMigr: <http://mu.semte.ch/vocabularies/migrations/>`

### Configuration
The migration service supports configuration via environment variables.
- `BATCH_SIZE`: amount of triples to insert in one go for a Turtle migration (default: 12000)
- `MINIMUM_BATCH_SIZE`: if the batch size drops below this number the service will stop with an error. (default: 100)
- `COUNT_BATCH_SIZE`: number of executed migrations to retrieve from the database in one go (default: 10000). 
*NOTE*: Make sure this is lower or equal to the maximum number of rows returned by the SPARQL endpoint.

This microservice is based on the [mu-ruby template](https://github.com/mu-semtech/mu-ruby-template) and supports the environment variables documented in its [README](https://github.com/mu-semtech/mu-ruby-template#configuration).

## Discussions
### Large datasets and batch size
Triple stores typically can only handle a certain amount of triples to be ingested per request. The migration service supports batching to split of large datasets in multiple requests. This can be configured with the `BATCH_SIZE` environment variable. If an error occurs during batch ingestion the batch size will be halved and the request retried until `MINIMUM_BATCH_SIZE` is reached. At this point an error will be thrown.

To make sure a dataset is loaded completely it will first be ingested into a temporary graph, on success the contents will be added to the target graph with a SPARQL Graph query.

### Working with mu-authorization
Experimental: You can hook the migrations service onto mu-authorization.  The migrations service will add the `mu-auth-sudo` header and execute migrations with elevated priviledges.  Support is experimental and we'd love to hear about your experience with this feature so we can harden it.

