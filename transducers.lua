-- A reinterpretation of Clojure Transducers for Lua.
-- http://clojure.org/transducers
-- http://blog.cognitect.com/blog/2014/8/6/transducers-are-coming

-- Create a table to store our exported values.
local exports = {}

-- Given a value, returns value plus "reduced" function which is used 
-- as a unique message identity. Used as a message passing mechanism for
-- `reduce()` to allow for early termination of reduction.
--
-- @TODO may want to switch to boxing reduced values in a table so I can add
-- something like preservingReduced which will be compatible with non-savvy
-- reduce functions.
local function reduced(v)
  return v, reduced
end
exports.reduced = reduced

-- Reduce an iterator function into a value.
-- `step` is the reducing function.
-- `seed` is the seed value for reduction.
-- `iter` is an iterator function. `...` allows for the additional state
-- variables that are returned from stateless iterator factories like `ipairs`.
--
-- Example:
--
--     reduce(sum, 0, ipairs{1, 2, 3})
local function reduce(step, seed, iter, ...)
  local result, msg = seed, nil
  -- Note `reduce` will work for iterators that return a single value or a
  -- pair of values... If a pair is returned, `b` is considered the value
  -- to reduce. This is handy if you want to consume standard iterators, like
  -- those returned from `ipairs` or `pairs`.
  for a, b in iter, ... do
    -- Allow `step` to return a result and an optional message.
    result, msg = step(result, b or a)
    -- If step returned a `msg`, then return early. This is useful for reporting
    -- errors during reduction or halting reduction early.
    if msg == reduced then return result end
  end
  -- Return result along with "finished" message.
  return result
end
exports.reduce = reduce

-- Define a generic reduce-like function for almost any type of value.
-- You can reduce iterators, single values, even `nil` to a value.
--
-- `transduce` is a lot like `reduce`, but has one magical difference:
-- `xform` is a function that takes a `step` function and returns a new `step`
-- function. With this foundation, we can chain together transformations that
-- have the same end result as `map`, `filter`, etc, but don't create interim
-- collections.
--
-- `transduce` takes an `xform` stepping function, a `result` value and returns
-- the folded result of our calculation.
--
-- Typical use:
--
--     xform = map(inc)
--     transduce(xform, sum, 0, ipairs{1, 2, 3})
--     > 9
local function transduce(xform, step, seed, iter, ...)
  -- Transform stepping function with transforming function.
  -- Then fold over `thing` using transformed `step` function and `result`
  -- seed value.
  return reduce(xform(step), seed, iter, ...)
end
exports.transduce = transduce

-- Insert value into table, mutating table.
-- Returns table.
local function append(t, v)
  table.insert(t, v)
  return t
end
exports.append = append

-- Transform an iterator through an `xform` function, appending results to
-- `into_table`. Mutates `into_table`.
--
--     into({}, map(is_even), ipairs {1, 2, 3})
--
-- If you're familiar with Clojure's `into`, you'll note that this is a bit of
-- a twist on the original. In Clojure sequences implement a sequence interface.
-- In Lua we use iterator factories to return a consistant iterator interface.
-- Hence, `into` takes an iterator function and optional state variables.
local function into(into_table, xform, iter, ...)
  return transduce(xform, append, into_table, iter, ...)
end
exports.into = into

local function id(thing)
  return thing
end
exports.id = id

-- Compose 2 functions.
local function comp2(z, y)
  return function(x) return z(y(x)) end
end

-- Compose multiple functions of one argument into a single function of one
-- argument that will transform argument through each function, starting with
-- the last in the list.
--
-- `compose(z, y)` can be read as "z after y". Or to put it another way,
-- `z(y(x))` is equivalent to `compose(z, y)(x)`.
-- https://en.wikipedia.org/wiki/Function_composition_%28computer_science%29
-- Returns the composed function.
local function comp(z, y, ...)
  return reduce(comp2, z or id, ipairs{y, ...})
end
exports.comp = comp

-- Map all values using function `a2b`.
-- Returns `xform` function.
local function map(a2b)
  return function(step)
    return function(result, input)
      return step(result, a2b(input))
    end
  end
end
exports.map = map

-- Given inputs that are tables, `cat` will step through all values in tables
-- and append to reduction.
-- More concretely: imagine you have an iterator of tables. `cat` conceptually
-- "flattens" the tables, reducing over each of the values of each of the tables.
local function cat(step)
  return function(result, input)
    return reduce(step, result, ipairs(input))
  end
end
exports.cat = cat

-- Expand a seqence into a sequence of tables, then flatten those tables using
-- cat. This allows you to expand a single input into multiple inputs.
local function mapcat(a2b)
  return comp(map(a2b), cat)
end
exports.mapcat = mapcat

-- Define `filter` in terms of a fold `step` transformation.
-- Throws out any value that does not pass `predicate` test function.
-- Returns `xform` function.
local function filter(predicate)
  return function(step)
    return function(result, input)
      if predicate(input) then
        -- If test passes, step input
        return step(result, input)
      else
        -- Otherwise skip input. Throw it away by returning previous result.
        return result
      end
    end
  end
end
exports.filter = filter

-- Reject values that do not pass `predicate` test function.
-- Returns `xform` function.
-- @TODO may want to rename this to `remove` for parity with Clojure.
local function reject(predicate)
  return function(step)
    return function(result, input)
      -- We'll reimplement the logic and hard-code a logical `not` because it's
      -- a bit faster than transforming the predicate function itself.
      if not predicate(input) then
        -- If test passes, step input
        return step(result, input)
      else
        -- Otherwise skip input. Throw it away by returning previous result.
        return result
      end
    end
  end
end
exports.reject = reject

-- Transform any reducing `step` function, returning a new `step` function that
-- collapses adjacent duplicates.
local function dedupe(step)
  -- This function is stateful. Use prev closure variable to keep track of
  -- @note if this function is called from multiple locations, it could cause
  -- state problems. Be smart.
  local prev
  return function(result, input)
    local is_unique = prev ~= input
    prev = input
    if is_unique then
      return step(result, input)
    else
      return result
    end
  end
end
exports.dedupe = dedupe

-- A stateful transform that will create a reducer that will reduce every
-- permutation created by `step_reduction` and `reduction`.
-- Returns `xform` function.
local function reductions(step_reduction, reduction)
  return function(step)
    return function(result, input)
      -- Step reduction to create a permutation of reduction.
      reduction = step_reduction(reduction, input)
      return step(result, reduction)
    end
  end
end
exports.reductions = reductions

-- Take first `n` values, then stop reduction.
-- Returns `xform` function.
local function take(n)
  return function(step)
    return function (result, input)
      if n > 0 then
        n = n - 1
        -- Keep taking values until a value fails `predicate` test function.
        return step(result, input)
      else
        -- When predicate fails, end reduction by sending `reduced` message.
        return reduced(result)
      end
    end
  end
end
exports.take = take

-- Take values until `predicate` returns false. Then stop reduction.
-- Returns `xform` function.
local function take_while(predicate)
  return function(step)
    return function (result, input)
      if predicate(input) then
        -- Keep taking values until a value fails `predicate` test function.
        return step(result, input)
      else
        -- When predicate fails, end reduction by sending `reduced` message.
        return reduced(result)
      end
    end
  end
end
exports.take_while = take_while

--[[
@TODO take_nth
https://clojure.github.io/clojure/branch-master/clojure.core-api.html#clojure.core/take-nth

@TODO drop
https://clojure.github.io/clojure/branch-master/clojure.core-api.html#clojure.core/drop

@TODO drop-last
https://clojure.github.io/clojure/branch-master/clojure.core-api.html#clojure.core/drop-last

@TODO drop-while
https://clojure.github.io/clojure/branch-master/clojure.core-api.html#clojure.core/drop-while

]]--

return exports
