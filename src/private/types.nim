## Internal type definitions for Dup/Duploy
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

type
  DatabaseType* {.pure.} = enum
    MySQL, PostgreSQL, None
  DatabaseConfig* = object
    kind*: DatabaseType
    username*: string
    password*: string
    name*: string
  DBError* = object of IOError
  DBConfigError* = object of DBError
