local transducers = require("transducers")
local reduce = transducers.reduce
local transduce = transducers.transduce
local lazily = transducers.lazily
local filter = transducers.filter
local map = transducers.map
local comp = transducers.comp
local ipairs_rev = transducers.ipairs_rev

local function suite(msg, callback)
  print(msg)
  callback()
end

local function test(truthy, msg)
  msg = msg or ""
  assert(truthy, "⚠  " .. msg)
  print("• " .. msg)
end

local function equal(x, y, msg)
  msg = msg or ""
  assert(x == y, "⚠️  " .. msg .. " (" .. tostring(x) .. " ~= " .. tostring(y) .. ")")
  print("• " .. msg)
end

local function is_odd(x)
  return (x % 2) == 1
end

local function add_one(x)
  return x + 1
end

suite("lazily() should transform values", function ()
  local n = {1, 2}

  local y = lazily(map(add_one), ipairs(n))

  local i, v = y()
  equal(v, 2, "Mapped 1 to 2")
  i, v = y()
  equal(v, 3, "Mapped 2 to 3")
  i, v = y()
  equal(v, nil, "Returns nil at end of iteration")
end)

suite("lazily() should not yield filtered values", function ()
  local n = {1, 2, 3}

  local y = lazily(filter(is_odd), ipairs(n))

  local i, v = y()
  equal(v, 1, "Kept 1")
  i, v = y()
  equal(v, 3, "Filtered 2, kept 3")
  i, v = y()
  equal(v, nil, "Returns nil at end of iteration")
end)

suite("ipairs_rev() should iterate from RTL", function ()
  local n = {1, 2, 3}

  local iter, state, i = ipairs_rev(n)

  equal(iter(state, i), 3, "Started iteration from end of list")

end)


suite("comp() compose from RTL", function ()
  local function greet(name)
    return "Hello, " .. name .. "!"
  end

  local welcome = comp(greet, string.upper)

  equal(welcome("bob"), "Hello, BOB!", "Composed RTL")

end)