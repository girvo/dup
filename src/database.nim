## Database handling for dup
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

import json
import strutils
import ./private/types

proc newDBMySQL* (password: string, name: string): DatabaseConfig =
  return DatabaseConfig(
    kind: MySQL,
    username: "admin",
    password: password,
    name: name)

proc newDBPostgreSQL* (username: string, password: string, name: string): DatabaseConfig =
  return DatabaseConfig(
    kind: PostgreSQL,
    username: username,
    password: password,
    name: name)

proc newDBNone* (): DatabaseConfig =
  return DatabaseConfig(kind: None)

## Gets an item from a given JsonNode, checking for nil
## Raises a DBConfigError if there is no specified key with that name
proc getString (config: JsonNode, key: string): string =
  let s = config.getOrDefault(key)
  if s.isNil:
    raise newException(
      DBConfigError,
      "No '" & key & "' key defined in the 'db' config object")
  else: return s.str

proc newDatabaseConfig* (config: JsonNode): DatabaseConfig =
  ## Proc assumes the "db" object from the .up.json has been passed in
  let dbType = config.getOrDefault("type")
  if dbType.isNil:
    raise newException(
      DBConfigError,
      "No 'type' key specified in 'db' config object")
  else:
    case dbType.str.toLowerAscii()
    of "mysql":
      let
        password = config.getString("password")
        name = config.getString("name")
      return newDBMySQL(password, name)
    of "postgres":
      let
        password = config.getString("password")
        name = config.getString("name")
        username = config.getString("user")
      return newDBPostgreSQL(username, password, name)
    of "none":
      return newDBNone()
    else:
      raise newException(
        DBConfigError,
        "Invalid 'type' value specified in 'db' config object")

proc getDataVolumeBinding* (conf: DatabaseConfig): string =
  case conf.getKind
  of MySQL:
    return "/var/lib/mysql"
  of PostgreSQL:
    return "/var/lib/postgres"
  of None:
    return ""
  else:
    raise newException(
      DBConfigError,
      "Invalid database type given")
