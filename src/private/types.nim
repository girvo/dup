## Internal type definitions for Dup/Duploy
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

type
  DatabaseType* = enum
    ## Used for DatabaseConfig ADT
    MySQL, PostgreSQL, None
  DatabaseConfig* = ref object
    ## DatabaseConfig ADT
    case kind: DatabaseType
    of PostgreSQL:
      name*: string
    else:
      discard
    username*: string
    password*: string

  ## Error types
  DBError* = object of IOError
  DBConfigError* = object of DBError

proc getKind*(s: DatabaseConfig): DatabaseType = s.kind

proc newDBNone(): DatabaseConfig =
  ## Creates a new DatabaseConfig of the "None" type
  result = DatabaseConfig(kind: None)

proc newDBMySQL(password: string, name: string): DatabaseConfig =
  ## Creates a new DatabaseConfig of the "MySQL" type
  result = DatabaseConfig(
    kind: MySQL,
    username: "admin",
    password: password,
    name: name)

proc newDBPostgreSQL(password: string, name: string, username: string): DatabaseConfig =
  ## Creates a new DatabaseConfig of the "PostgreSQL" type
  result = DatabaseConfig(
    kind: PostgreSQL,
    username: username,
    password: password,
    name: name)

proc newDBConfig*(dbType: DatabaseType, username = "", password = "", name = ""): DatabaseConfig =
  ## Creates a new database configuration based on a given type param
  case dbType
  of MySQL:
    result = newDBMySQL(password, name)
  of PostgreSQL:
    result = newDBPostgreSQL(password, name, username)
  of None:
    result = newDBNone()
  else:
    raise newException(DBConfigError, "Invalid DatabaseType specified, please check your config")
