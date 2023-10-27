## Tutorials
### Primer

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
