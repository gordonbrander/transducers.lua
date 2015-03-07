package = "Transducers"
version = "scm-1"
source = {
  url = "git://github.com/gordonbrander/transducers"
}
description = {
  summary = "Composable list transformations inspired by Clojure transducers",
  detailed = [[
A re-interpretation of Clojure's Transducers for Lua.
Transducers are composable algorithmic transformations.
Learn more about Transducers here: http://clojure.org/transducers.
  ]],
  homepage = "https://github.com/gordonbrander/transducers",
  license = "MIT/X11"
}
dependencies = {
  "lua ~> 5.1"
}
build = {
  type = "builtin",
  modules = {
    ["transducers"] = "transducers.lua"
  }
}