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

`dup` is a tiny wrapper over Docker that loads a declarative JSON file for a given project to manage containers (especially stateful database containers) in a sane way. It was created due to frustration with [docker-compose](https://docs.docker.com/compose/) and it's issues with volume-only containers: a prerequisite for easy local web development. Three containers are created, prefixed with your declared project name (no defaulting to folder names here!): `-web`, `-db` and `-data`.

## New features

The main new feature in v0.3.7 is the addition of `--build-arg env=dev` to the `dup build` command. This is a temporary measure until I expose build-args to the user via the `.up.json` file. This feature means you **need** to have this line in your base `Dockerfile`:

```Dockerfile
ARG env
```

This is the bare minimum. You will likely want to instead do the following:

```Dockerfile
ARG env=prod
```

This will default the argument to `prod`, and fix the `One or more build-args [env] were not consumed, failing build.` error that will otherwise be triggered. An example of how to leverage this feature to allow for a singular production `Dockerfile` that has developer tools added on top, assuming two files: `conf/start.prod.sh` which is the standard entry-point, and `conf/start.dev.sh` which is the development entry-point that adds extra tools is as follows:

```Dockerfile
###
# This is both a test of Skate as a tool, as well as build-args for Docker
##
FROM studionone/node6:latest

# Use a different entrypoint for development vs production
ARG env=prod
ADD conf/start.$env.sh /start.sh
RUN chmod +x /start.sh

ADD code /app
WORKDIR /app
RUN npm install

EXPOSE 8080

ENTRYPOINT /start.sh
```

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

## License

MIT. See [LICENSE.md](/LICENSE.md) for details.
