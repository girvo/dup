## Top-level project configuration handling
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

import future
import json
import ./private/types

proc createProjectConfig*(raw: JsonNode, dbConf: DatabaseConfig): ProjectConfig =
  let name = raw.getOrDefault("project").getStr()
  if name == "":
    raise newException(ProjectConfigError, "'project' key ")
  let port = raw.getOrDefault("port").getStr("") # Default to empty
  result = newProjectConfig(name, dbConf, port, @[], @[])

proc web*(config: ProjectConfig): string =
  result = config.name & "-web"

proc db*(config: ProjectConfig): string =
  result = config.name & "-db"

proc data*(config: ProjectConfig): string =
  result = config.name & "-data"
