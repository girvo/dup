## Database handling for dup
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

import json
import strutils
import private/types

proc newDBConfig*(config: JsonNode): DatabaseConfig =
  ## Instantiates the DatabaseConfig object from a parsed JsonNode
  ## Proc assumes the "db" object from the .up.json has been passed in
  let dbType = config.getOrDefault("type")
  if dbType.isNil:
    raise newException(
      DBConfigError,
      "No 'type' key specified in 'db' config object")
  # Match the db.type string to our database types
  case dbType.getStr().toLowerAscii()
  of "mysql":
    result = MySQL.newDBConfig(
      config.getOrDefault("pass").getStr(),
      config.getOrDefault("name").getStr())
  of "postgres":
    result = PostgreSQL.newDBConfig(
      config.getOrDefault("pass").getStr(),
      config.getOrDefault("name").getStr(),
      config.getOrDefault("user").getStr())
  of "none":
    result = None.newDBConfig()
  else:
    raise newException(
      DBConfigError,
      "Invalid 'type' value specified in 'db' config object")

proc getDataVolumeBinding* (conf: DatabaseConfig): string =
  case conf.kind
  of MySQL:
    result = "/var/lib/mysql"
  of PostgreSQL:
    result = "/var/lib/postgres"
  of None:
    result = ""
  else:
    raise newException(
      DBConfigError,
      "Invalid database type given")
