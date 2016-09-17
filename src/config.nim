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
    raise newException(
      ProjectConfigError,
      "'project' key ")
  result = newProjectConfig(name, dbConf, @[], @[])
