## Internal type definitions for Dup/Duploy
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

## Database types
type
  DatabaseType* = enum
    ## Used for DatabaseConfig ADT
    MySQL, PostgreSQL, MongoDB, None
  DatabaseConfig* = ref object
    ## DatabaseConfig ADT
    case kind: DatabaseType
    of PostgreSQL:
      username*: string
      image*: string
    else: discard
    # Shared properties across the ADT -- empty for None et al.
    name*: string
    password*: string

type
  DBError* = object of IOError ## Top-level database error
  DBConfigError* = object of DBError ## Database configuration error

proc kind*(s: DatabaseConfig): DatabaseType =
  ## Getter for the "kind" property
  result = s.kind

proc newDBNone(): DatabaseConfig {.raises: [].} =
  ## Creates a new DatabaseConfig of the "None" type
  result = DatabaseConfig(kind: None)

proc newDBMySQL(pass: string, name: string): DatabaseConfig
                {.raises: [DBConfigError].} =
  ## Creates a new DatabaseConfig of the "MySQL" type
  if pass.len == 0: raise newException(DBConfigError, "'pass' must be set and non-empty")
  if name.len == 0: raise newException(DBConfigError, "'name' must be set and non-empty")
  result = DatabaseConfig(
    kind: MySQL,
    password: pass,
    name: name)

proc newDBPostgreSQL(pass: string, name: string, user: string, image: string): DatabaseConfig
                     {.raises: [DBConfigError].} =
  ## Creates a new DatabaseConfig of the "PostgreSQL" type
  if pass.len == 0: raise newException(DBConfigError, "'pass' must be set and non-empty")
  if name.len == 0: raise newException(DBConfigError, "'name' must be set and non-empty")
  if user.len == 0: raise newException(DBConfigError, "'user' must be set and non-empty")
  result = DatabaseConfig(
    kind: PostgreSQL,
    password: pass,
    name: name,
    username: user,
    image: image)

proc newDBMongoDB*(): DatabaseConfig {.raises: [].} =
  result = DatabaseConfig(
    kind: MongoDB,
    password: "",
    name: "")

proc newDBConfig*(dbType: DatabaseType, pass = "", name = "",
                  user = "", image = ""): DatabaseConfig {.raises: [DBConfigError].} =
  ## Creates a new database configuration based on a given type param
  case dbType
  of MySQL:
    result = newDBMySQL(pass, name)
  of PostgreSQL:
    result = newDBPostgreSQL(pass, name, user, image)
  of MongoDB:
    result = newDBMongoDB()
  of None:
    result = newDBNone()
  else:
    raise newException(DBConfigError, "Unknown DatabaseType specified")

## Config types
type
  Arg* = tuple[
    name: string,
    value: string]
  Args* = seq[Arg]
  BuildArgs* = seq[Arg]
  ProjectConfig* = ref object
    name*: string
    port*: string
    volume*: string
    dockerfile*: string
    dbConf*: DatabaseConfig
    envVars*: Args
    buildArgs*: BuildArgs

type
  ConfigError* = object of IOError
  ProjectConfigError* = object of ConfigError

proc newArg*(name: string, value: string): Arg {.raises: [].} =
  ## Create an arg given two strings
  result = (
    name: name,
    value: value)

proc newProjectConfig*(name: string, dbConf: DatabaseConfig, port: string,
                       envVars: Args, buildArgs: BuildArgs, volume: string,
                       dockerfile: string): ProjectConfig {.raises: [].} =
  ## Build a new project config (used internally)
  ## TODO: Refactor the order of arguments to this proc
  result = ProjectConfig(
    name: name,
    port: port,
    volume: volume,
    dockerfile: dockerfile,
    dbConf: dbConf,
    envVars: envVars,
    buildArgs: buildArgs)

## Version number handling for Docker
type
  VersionNumber* = tuple
    major: int
    minor: int
    patch: int

proc newVersionNumber*(major, minor, patch: int): VersionNumber {.raises: [].} =
  result = (
    major,
    minor,
    patch)
