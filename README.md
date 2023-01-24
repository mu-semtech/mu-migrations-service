# mu-migrations-service

The mu-migrations-service runs migrations on the database.  This currently includes SPARQL queries (`*.sparql`) and Turtle files (`*.ttl`). We intend more formats to be supported in the future.

## Tutorials

### Add the migrations service to a stack
To install the migrations service in your project, add the migrations-service to
the `docker-compose.yml` file of your mu-project by adding the following snippet:

```
    migrations:
      image: semtech/mu-migrations-service:0.8.0
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
### Primer
![](http://mu.semte.ch/wp-content/uploads/2017/05/migrations-1024x683.png)

What is an application without the data it manipulates?  Very little indeed.  Storing the initial content and updating the data model is often solved with migrations.  In this primer we’ll quickly introduce you to service.  We’ll briefly go over the when and how.

There’s often a need to insert standard content into the application.  A common example is the addition of a standard administration user which, in its turn, is allowed to create new users.  This is called the *seeding* of the data.  We used to rely on the vendor-specific toLoad folder of the Virtuoso docker for this purpose.  That approach has been abandoned.  Another common issue you may encounter is data migration.  You’d expect this issue to be of minimal interest given the semantic model, yet in practice we do encounter it.  The migrations-service is, as the name suggests, is well-suited for data migrations.

Throw away your old toLoad folder, start using migrations.  They are easier to understand, easier to reason on, and more flexible.  As a bonus, default content and changes in the model are now more easily found in the structure of your `mu-project`.

So how does the migrations-service operate, and how do you add it to your pipeline?  A brief overview is in place.

#### Inner workings of the migrations-service
The migrations-service launches when the pipeline is started.  It checks which migrations are available and have not been ran before, and it runs these migrations.  It registers the fact that a migration has ran in the triplestore for later inspection.

The migrations service checks the migrations in lexicographical order.  In Rails, it has become a common practice to prefix the name of the migration with the current unix timestamp.  You can use *`date +%s`* to return this value in your Linux shell.  As an example, we could have _1492676240-standard-users.ttl* to indicate the seeding of standard users.

When you create a new migration and want it to run immediately, just restart the migrations-service.  This service hums in the background, easy as can be.

### Seeding data
As your application gets launched for the first time, it would ideally show some demo content to the user.  Admin accounts are another common purpose.  We can insert the necessary data by adding a Turtle file to the *./config/migrations* folder and running the migrations from there.

Getting to know Turtle is a valuable trait.  You can find the specification at [the W3C](https://www.w3.org/TR/turtle/).  We could explain it tersely as a plain text file containing the listing of all triples you’d like to describe.  You can list them as *subject predicate object*, ending each triple with a dot.  URIs are enclosed between smaller than and greater than signs, like *`<http://mu.semte.ch/vocabularies/core/uuid>`*.  If you’ve defined a *mu* prefix, you can abbreviate that as *mu:uuid*. The name *a* is the equivalent of *rdf:type*.  Much like in sentences, you can split triples using a dot (.), semicolon (;) or comma (,) .  If you want to list triples in which you reuse the predicate, you can use a semicolon as a separator and not repeat the triple.  The same can be done for repeating the predicate and the object, in which case you use the comma separator.  An example makes all this more tangible:

```t
    @prefix dct: <http://purl.org/dc/terms/> .
    @prefix tac: <http://tasks-at-hand.com/vocabularies/core/> .
    @prefix ext: <http://mu.semte.ch/vocabularies/ext/> .
    @prefix mu: <http://mu.semte.ch/vocabularies/core/> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    
    <http://tasks-at-hand.com/resources/statuses/not_started>
          a tac:Status;
          mu:uuid "c864df1e-25a3-11e7-96cf-a71dfa8572e8";
          dct:title "not started".
    <http://tasks-at-hand.com/resources/statuses/ongoing>
          a tac:Status;
          mu:uuid "cea22080-25a3-11e7-95ea-0fe743380224";
          dct:title "ongoing".
    <http://tasks-at-hand.com/resources/statuses/done>
          a tac:Status;
          mu:uuid "d681f618-25a3-11e7-8b26-47ee72b3ff33";
          dct:title "done".
```

So where do you find  the data.  Oftentimes, we create standard data through the interface, list it using a SPARQL query, and convert the results into a turtle file for easy understanding.  Saving triples twice doesn’t create duplicates, so you can safely add the migration and let it insert the data already in your database.

### Migrating the data-model

One of the broader concepts of RDF is that we think strongly about the model before we start using it.  When studying a model in depth, and reusing what others have built, updates to the model become much more rare. When you create your own model, the model will need to be defined, and refined.  If you’re defining and refining your own predicates for your application, the model may evolve over time.  The migration helps you move data from one model to another.

The *ext* namespace (defined as *`<http://mu.semte.ch/vocabularies/ext/>`*) can be used for yet-to-define predicates.  Say that your model evolves over time, you can use SPARQL queries in the migrations-service to convert the model from one shape to another.

We often advise the use of the ext namespace for properties which are yet to be defined correctly.  Perhaps you’re building your application and you don’t want to be sidetracked in a vocabulary-hunt.  You know the definition of the property and add it to your model.  Assume you’ve used *ext:title* as the definition of the title property.  At a later stage, you search for the right vocabulary and notice that *dct:title* is the generally accepted standard.  You update your *domain.lisp* to use the new predicate, but your data is still stale.  You can run a SPARQL query to fix it on your data, but what about the testing and production server?  By placing the query in the migrations service, all platforms will be updated accordingly.

An example SPARQL query migration that would change the *ext:title* predicate to *dct:title* could be named *1492677626-change-ext-title-to-dct-title.sparql* and have the following contents:
```conf
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    
    INSERT {
      GRAPH <http://mu.semte.ch/application> {
        ?s dct:title ?o.
      }
    }
    DELETE {
      GRAPH <http://mu.semte.ch/application> {
        ?s ext:title ?o.
      }
    }
    WHERE {
      GRAPH <http://mu.semte.ch/application> {
        ?s ext:title ?o.
      }
    }
```

*[Primer](#primer), [Seeding data](#seeding-data) and [Migrating the data-model](#migrating-the-data-model) have been adapted from Aad Versteden's mu.semte.ch article. You can view it [here](https://mu.semte.ch/2017/04/20/data-seeding-and-migration-with-the-migrations-service/)*


### Large datasets and batch size
Triple stores typically can only handle a certain amount of triples to be ingested per request. The migration service supports batching to split of large datasets in multiple requests. This can be configured with the `BATCH_SIZE` environment variable. If an error occurs during batch ingestion the batch size will be halved and the request retried until `MINIMUM_BATCH_SIZE` is reached. At this point an error will be thrown.

To make sure a dataset is loaded completely it will first be ingested into a temporary graph, on success the contents will be added to the target graph with a SPARQL Graph query.

### Working with mu-authorization
Experimental: You can hook the migrations service onto mu-authorization.  The migrations service will add the `mu-auth-sudo` header and execute migrations with elevated priviledges.  Support is experimental and we'd love to hear about your experience with this feature so we can harden it.

