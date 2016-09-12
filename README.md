# dup: local Docker web development

```
Declaratively define and run stateful Docker containers for web development.

Usage:
  dup up                   Starts the containers
  dup down                 Stops and removes the containers
  dup init                 Initialises the "-data" container
  dup status               Checks status of the "-web" and "-db" containers
  dup build [--no-cache]   Builds the web container's image
  dup (-h | --help)        Prints this help message
  dup --version            Prints the installed version
```

`dup` is a tiny wrapper over Docker that loads a declarative JSON file for a given project to manage containers (especially stateful database containers) in a sane way. It was created due to frustration with [docker-compose](https://docs.docker.com/compose/) and it's issues with volume-only containers: a prerequisite for easy local web development. Three containers are created, prefixed with your declared project name (no defaulting to folder names here!): `-web`, `-db` and `-data`.

## `.up.json`

In the root of your project, next to the `Dockerfile`, you will need a JSON file `.up.json`, that contains at least this:

```json
{
    "project": "project-name-here",
    "db": {
        "type": "mysql-or-postgres",
        "name": "database-name",
        "pass": "password-for-admin-or-root-user"
    }
}
```

And can also contain these optional fields:

```json
{
    "volume": "local-folder:/container/folder",
    "port": "host:container",
    "env": {
        "ENV_VAR": "value"
    },
    "buildArgs": {
        "example": "build-arg"
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
    "KEY_TWO": "valueTwo",
    "VIRTUAL_HOST": "example.docker"
}
```

Specify a different code directory volume map (host directory is automatically prepended with current directory). By default, this is set to `code:/var/www`:

```json
"volume": "relative-host-dir:/absolute/container/dir"
```

## Code

Your code is mounted as a volume into the `-web` container from the `code/` directory in the root of your project. This can be any language, though PHP and Node.js are the most tested at this point in time, with the `studionone/apache-php5:base` and `studionone/nginx-php5:base` base images.

## Databases

Currently, `dup` handles MySQL, using the [tutum/mysql:latest](https://github.com/tutumcloud/mysql) Docker image. PostgreSQL is now supported, via the [sameersbn/postgresql:latest](https://github.com/sameersbn/docker-postgresql) Docker image. Persistence of your database is handled by leveraging a "volume-only" container, which ensures that your database persists across destruction of the container. To completely destroy your database, remove the `.up.state` file and `docker rm` the `-data` container.

The database user that is setup by default under `tutum/mysql` is `admin`, and the password for that user is declared in `.up.json`.

Alternatively, to not use a database, set the `db` object to:

```json
"db": {
  "type": "none"
}
```

## Troubleshooting

### OSX: `could not import: pcre_free_study`

You'll need to install a newer version of the `pcre` library: `brew install pcre` should fix this issue.

## Building

### OS X

You'll need `make`, `nim` and it's package manager `nimble`. Clone the repository, run `nimble install`, and then `make`. The binary will be in `./build`.

### Linux

If you're building natively, then you can follow the [same instructions](#os-x) as OSX. If you're running OSX but want to cross-compile, run `make linux`.

### Release builds

```sh
$ make release
```

Linux builds are `-d:release` by default.

## License

MIT. See [LICENSE.md](/LICENSE.md) for details.
