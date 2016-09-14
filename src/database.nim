## Database handling for dup
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

import json
import strutils
import ./private/types

proc newDBMySQL* (password: string, name: string): DatabaseConfig =
  return DatabaseConfig(
    kind: DatabaseType.MySQL,
    username: "admin",
    password: password,
    name: name)

proc newDBPostgreSQL* (username: string, password: string, name: string): DatabaseConfig =
  return DatabaseConfig(
    kind: DatabaseType.PostgreSQL,
    username: username,
    password: password,
    name: name)

proc newDBNone* (): DatabaseConfig =
  return DatabaseConfig(
    kind: DatabaseType.None,
    username: "",
    password: "")

proc getPassword (config: JsonNode): string =
  let password = config.getOrDefault("password")
  if password.isNil:
    raise newException(
      DBConfigError,
      "No 'password' key defined in 'db' config object")
  else: return password.str

proc getName (config: JsonNode): string =
  let name = config.getOrDefault("name")
  if name.isNil:
    raise newException(
      DBConfigError,
      "No 'name' key defined in 'db' config object")
  else: return name.str

proc getUsername (config: JsonNode): string =
  let username = config.getOrDefault("user")
  if username.isNil:
    raise newException(
      DBConfigError,
      "No 'name' key defined in 'db' config object")
  else: return username.str

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
        password = getPassword(config)
        name = getName(config)
      return newDBMySQL(password, name)
    of "postgres":
      let
        password = getPassword(config)
        name = getName(config)
        username = getUsername(config)
      return newDBPostgreSQL(username, password, name)
    of "none":
      return newDBNone()
    else:
      raise newException(
        DBConfigError,
        "Invalid 'type' value specified in 'db' config object")

proc getDataVolumeBinding* (conf: DatabaseConfig): string =
  case conf.kind
  of DatabaseType.MySQL:
    return "/var/lib/mysql"
  of DatabaseType.PostgreSQL:
    return "/var/lib/postgres"
  of DatabaseType.None:
    return ""
  else:
    raise newException(
      DBConfigError,
      "Invalid database type given")
