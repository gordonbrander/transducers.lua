local transducers = require("transducers")
local reduce = transducers.reduce
local transduce = transducers.transduce
local filter = transducers.filter
local map = transducers.map
local comp = transducers.comp

local microtest = require("microtest")
local test, ok = microtest()

local function is_odd(x)
  return (x % 2) == 1
end

local function inc(x)
  return x + 1
end

local function sum(a, b)
  return a + b
end

function cat_a(s)
  return s .. "a"
end

function cat_b(s)
  return s .. "b"
end

test("comp()", function()
  local x = comp(cat_b, cat_a)
  ok(x("") == "ab", "comp executes from right to left")
end)

test("map()", function()
  local x = {1, 2}
  local y = transduce(map(inc), sum, 0, ipairs(x))
  ok(y == 5, "map changes all items in iterator")
end)