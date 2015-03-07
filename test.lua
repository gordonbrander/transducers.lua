local transducers = require("transducers")
local reduce = transducers.reduce
local transduce = transducers.transduce
local filter = transducers.filter
local reject = transducers.reject
local map = transducers.map
local into = transducers.into
local take = transducers.take
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

test("reduce()", function()
  local x = reduce(sum, 0, ipairs{1, 2, 3})
  ok(x == 6, "Reduce steps through values in an iterator, reducing a value")

  -- @TODO test for early end of reduction.
end)

test("comp()", function()
  local x = comp(cat_b, cat_a)
  ok(x("") == "ab", "comp executes from right to left")
end)

test("transduce(xf, step, seed, iter)", function()
  local x = {1, 2}
  local y = transduce(map(inc), sum, 0, ipairs(x))
  ok(y == 5, "Transduce transforms items in interator")
end)

test("into(t, xf, iter)", function()
  local x = {1, 2}
  local y = into(map(inc), ipairs(x))
  ok(y[1] == 2 and y[2] == 3, "into collects transformed values into table")
end)

test("map()", function()
  local x = {1, 2}
  local y = transduce(map(inc), sum, 0, ipairs(x))
  ok(y == 5, "map all items in iterator")
end)

test("filter()", function()
  local x = {1, 2}
  local y = transduce(filter(is_odd), sum, 0, ipairs(x))
  ok(y == 1, "filter removes items that don't pass the test")
end)

test("reject()", function()
  local x = {1, 2}
  local y = transduce(reject(is_odd), sum, 0, ipairs(x))
  ok(y == 2, "reject removes items that pass the test")
end)

test("test()", function()
  local x = {1, 2}
  local y = transduce(take(1), sum, 0, ipairs(x))
  ok(y == 1, "Take stops reduction after taking n items")
end)
