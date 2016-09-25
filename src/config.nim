## Top-level project configuration handling
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

import future
import json
import tables
import sequtils
import private/types

proc parseEnvTable*(rawEnv: Table[string, JsonNode]): Args
                   {.raises: [ProjectConfigError].} =
  ## Parses JsonNode tables into Args sequences
  result = @[]
  var
    arg: Arg
    value: string = ""
  for key, node in rawEnv:
    # Iterate over the table to create the Args seq
    value = node.getStr("")
    if value == "":
      raise newException(
        ProjectConfigError,
        "'env' object values must be non-empty strings")
    arg = newArg(key, value)
    result.add(arg)

proc createProjectConfig*(raw: JsonNode, dbConf: DatabaseConfig): ProjectConfig
                          {.raises: [ProjectConfigError].} =
  let name = raw.getOrDefault("project").getStr()
  if name == "":
    raise newException(ProjectConfigError, "'project' key ")
  let port = raw.getOrDefault("port").getStr("") # Default to empty
  let env = parseEnvTable(raw.getOrDefault("env").getFields())
  let buildArgs = parseEnvTable(raw.getOrDefault("buildArgs").getFields())
  result = newProjectConfig(name, dbConf, port, env, buildArgs)

proc webContainer*(config: ProjectConfig): string =
  ## Helper proc for getting web container name
  result = config.name & "-web"

proc dbContainer*(config: ProjectConfig): string =
  ## Helper proc for getting database container name
  result = config.name & "-db"

proc dataContainer*(config: ProjectConfig): string =
  ## Helper proc for getting data container name
  result = config.name & "-data"
