# dup: local Docker web development

```
Declaratively define and run stateful Docker containers for web development.

Usage:
  dup up                   Starts the containers
  dup down                 Stops and removes the containers
  dup init                 Initialises the "-data" container
  dup status               Not yet implemented
  dup build [--no-cache]   Builds the web container's image
  dup (-h | --help)        Prints this help message
  dup --version            Prints the installed version
```

`dup` is a tiny wrapper over Docker that loads a declarative JSON file for a given project to manage containers (especially stateful database containers) in a sane way. It was borne out of frustration with [docker-compose]() and it's issues with volume-only containers: a prerequisite for easy local web development. Three containers are created, prefixed with your declared project name (no defaulting to folder names here!): `-web`, `-db` and `-data`.

## `.up.json`

In the root of your project, next to the `Dockerfile`, you will need a JSON file `.up.json`, that follows this format:

```json
{
    "project": "project-name-here",
    "port": "host:container",
    "db": {
        "type": "mysql-or-postgres",
        "name": "database-name",
        "pass": "password-for-admin-or-root-user"
    }
}
```

### Optional config

All optional configs are keys on the top level config object.

Specify a Dockerfile (other than the root `Dockerfile`):

```json
    "dockerfile": "Dockerfile.local"
```

Specify environment variables for the web container:

```json
    "env": {
        "KEY_ONE": "valueOne",
        "KEY_TWO": "valueTwo"
    }
```

## Code

Your code is mounted as a volume into the `-web` container from the `code/` directory in the root of your project. This can be any language, though PHP and Node.js are the most tested at this point in time, with the `studionone/apache-php5:base` and `studionone/nginx-php5:base` base images.

## Databases

Currently, `dup` only handles MySQL, using the [tutum/mysql:latest](https://github.com/tutumcloud/mysql) Docker image. In the very near future (as at Nov 2015), PostgreSQL will also be supported. Persistence of your database is handled by leveraging a "volume-only" container, which ensures that your database persists across destruction of the container. To completely destroy your database, remove the `.up.state` file and `docker rm` the `-data` container.

The database user that is setup by default under `tutum/mysql` is `admin`, and the password for that user is declared in `.up.json`.

Alternatively, to not use a database, set the `db` object to:

```json
"db": {
  "type": "none"
}
```

## Building

### OS X

You'll need `make`, `nim` and it's package manager `nimble`. Clone the repository, run `nimble install`, and then `make`. The binary will be in `./build`.

### Linux

If you're building natively, then you can follow the [same instructions](#os-x) as OSX. If you're running OSX but want to cross-compile, run `make linux`.

## License

MIT. See [LICENSE.md](/LICENSE.md) for details.
