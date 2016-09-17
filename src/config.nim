## Top-level project configuration handling
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

import future
import json
import ./private/types

proc createProjectConfig*(raw: JsonNode, dbConf: DatabaseConfig): ProjectConfig =
  result = newProjectConfig("", dbConf, @[], @[])
