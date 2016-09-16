## Internal type definitions for Dup/Duploy
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

import future

{.experimental.}

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

proc getKind* (s: DatabaseConfig): DatabaseType = s.kind
