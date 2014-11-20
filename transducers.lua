-- A reinterpretation of Clojure Transducers for Lua.
-- http://clojure.org/transducers
-- http://blog.cognitect.com/blog/2014/8/6/transducers-are-coming

-- Create a table to store our exported values.
local exports = {}

-- Given a value, returns value plus "reduced" function which is used 
-- as a unique message identity. Used by `reduce_iterator` to allow for
-- early termination of reduction.
local function reduced(v)
  return v, "Finished reduction"
end
exports.reduced = reduced

-- Reduce an iterator function into a value.
-- `iter`, `state`, `at` are intended to be the return result of
-- an iterator factory function. `state` and `at` are optional and
-- are provided for looping over stateless iterators. You may pass just the
-- `iter` function if it is a stateful iterator.
--
-- Example:
--
--     reduce(sum, 0, ipairs{1, 2, 3})
--     > 9
local function reduce(step, seed, iter, state, at)
  local result, msg = seed, nil
  -- Note `reduce` will work for iterators that return a single value or a
  -- pair of values... If a pair is returned, `b` is considered the value
  -- to reduce. This is handy if you want to consume stateless iterators, like
  -- those returned from `ipairs` or `pairs`.
  for a, b in iter, state, at do
    -- Allow `step` to return a result and an optional message.
    result, msg = step(result, b or a)
    -- If step returned a `msg`, then return early. This is useful for reporting
    -- errors during reduction or halting reduction early.
    if msg then return result, msg end
  end
  -- Return result along with "finished" message.
  return reduced(result)
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
--     transduce(map(add_one), sum, 0, ipairs{1, 2, 3})
--     > 9
local function transduce(xform, step, seed, iter, state, at)
  -- Transform stepping function with transforming function.
  -- Then fold over `thing` using transformed `step` function and `result`
  -- seed value.
  return reduce(xform(step), seed, iter, state, at)
end
exports.transduce = transduce

local function apply_to(v, f)
  return f(v)
end
exports.apply_to = apply_to

local function prev_ipair(t, i)
  i = i - 1
  if i < 1 then
    return nil
  else
    return i, t[i]
  end
end

-- Iterate over a table in reverse, starting with last element.
local function ipairs_rev(t)
  return prev_ipair, t, #t + 1
end
exports.ipairs_rev = ipairs_rev

-- Compose multiple functions of one argument into a single function of one
-- argument that will transform argument through each function, starting with
-- the last in the list.
-- `compose(b, a)` can be read as "b after a". Or to put it another way,
-- `b(a(x))` is equivalent to `compose(b, a)(x)`.
-- https://en.wikipedia.org/wiki/Function_composition_%28computer_science%29
-- Returns the composed function.
local function comp(...)
  -- Capture magic `arg` variable.
  local fns = arg
  return function(v)
    -- Loop through all functions and transform value with each function
    -- successively. Feed transformed value to next function in line.
    return reduce(apply_to, v, ipairs_rev(fns))
  end
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

return exports
