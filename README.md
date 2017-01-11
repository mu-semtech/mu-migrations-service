# [WIP] mu-migrations-service

The mu-migrations-service runs migrations on the database.  This
currently includes only SPARQL queries.  We intend more formats to be
supported in the future.

This service is **Work In Progress** it does not operate yet, and its
semantics may change.

## How to

Migrations are specified in files, to be executed in the order of
their filename. The files may reside in subfolders. It is advised
to use the unix system time as the basis for the filename of your
migration, postfixed with a short name of what the migration performs.

### Specifying the migration

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
        - "./config/migrations:/data/migrations"
```        

The migration will be ran when the mu-migrations-service starts up,
and output about the status of the ran migrations will be written to
the database for later inspection.
