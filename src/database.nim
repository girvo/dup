## Database handling for dup
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

import json
import strutils
import private/types

proc newDBConfig*(config: JsonNode): DatabaseConfig {.raises: [DBConfigError].} =
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
      pass = config.getOrDefault("pass").getStr(),
      name = config.getOrDefault("name").getStr(),
      image = config.getOrDefault("image").getStr())
  of "postgres":
    result = PostgreSQL.newDBConfig(
      pass = config.getOrDefault("pass").getStr(),
      name = config.getOrDefault("name").getStr(),
      user = config.getOrDefault("user").getStr(),
      image = config.getOrDefault("image").getStr())
  of "mongodb":
    result = MongoDB.newDBConfig(
      image = config.getOrDefault("image").getStr())
  of "none":
    result = None.newDBConfig()
  else:
    raise newException(
      DBConfigError,
      "Invalid 'type' value specified in 'db' config object")

proc getVolumePath*(conf: DatabaseConfig): string {.raises: [].} =
  case conf.kind
  of MySQL:
    result = "/var/lib/mysql"
  of PostgreSQL:
    result = "/var/lib/postgres"
  of MongoDB:
    result = "/data/db"
  of None:
    result = ""

proc getImageName*(conf: DatabaseConfig): string {.raises: [].} =
  case conf.kind
  of MySQL:
    result = if conf.image == "": "mysql:5.6" else: conf.image
  of PostgreSQL:
    result = if conf.image == "": "postgres:9.5" else: conf.image
  of MongoDB:
    result = if conf.image == "": "mongo:3.3" else: conf.image
  of None:
    result = ""
