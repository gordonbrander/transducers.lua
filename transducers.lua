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
-- an iterator factory like `ipairs()`. `state` and `at` are optional and
-- are provided for looping over stateless iterators. You may pass just the
-- `iter` function if it is a stateful iterator.
--
-- Used by our more generic `reduce` function to handle iterator use cases.
local function reduce_iterator(step, seed, iter, state, at)
  local result, msg = seed, nil
  for i, v in iter, state, at do
    -- We pass `step` the previous result and the value returned by iterator.
    -- Note that we use an `i, v` return signiture. This matches the return
    -- value of `ipairs` and `pairs`. However, if `v` is nil, we will pass
    -- `i` as the value instead. This handles iterators that return a single
    -- value per turn.
    -- Allow `step` to return a result and an optional message.
    result, msg = step(result, v or i)
    -- If step returned a `msg`, then return early. This is useful for reporting
    -- errors during reduction or halting reduction early.
    if msg then return result, msg end
  end
  -- Return result along with "finished" message.
  return reduced(result)
end

-- Define a generic reduce function for almost any type of value. You can
-- reduce: stateful and stateless iterators, tables, single values, even `nil`.
--
-- `reduce` takes a `step` function, a `seed` value and returns the new folded
-- result of our calculation.
--
-- Typical use:
-- 
--     local x = reduce(sum, 0, {1, 2, 3})
--
local function reduce(step, seed, iter, state, at)
  local type_of_iter = type(iter)
  if type_of_iter == "function" then
    -- If `iter` is a function, we treat it as an iterator function.
    -- If it ain't an iterator, you'll probably get an error. Be smart.
    return reduce_iterator(step, seed, iter, state, at)
  elseif type_of_iter == "table" then
    -- If `iter` is a table, we'll provide a convenience syntax that passes the
    -- table through `ivalues` and then to `reduce_iterator`.
    return reduce_iterator(step, seed, ipairs(iter))
  elseif iter == nil then
    -- Nil values get no step at all. Return seed as "reduced" value.
    return reduced(seed)
  else
    -- Other non-iterator, non-table, non-nil values are treated as an iterator
    -- yielding a single item -- themselves. We reduce them one step.
    return reduced(step(seed, iter))
  end
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
--     transduce(map(add_one), sum, 0, {1, 2, 3})
--     > 9
local function transduce(xform, step, seed, iter, state, at)
  -- Transform stepping function with transforming function.
  -- Then fold over `thing` using transformed `step` function and `result`
  -- seed value.
  return reduce(xform(step), seed, iter, state, at)
end
exports.transduce = transduce

local function append(t, v)
  table.insert(t, v)
  return t
end
exports.append = append

-- Collect all values from an iterator into a table.
-- Returns collected values.
-- Example:
--
--     local clone = collect({1, 2, 3})
local function collect(iter, state, at)
  return reduce(append, {}, iter, state, at)
end
exports.collect = collect

local function apply_to(v, f)
  return f(v)
end

-- Compose multiple functions of one argument into a single function of one
-- argument that will transform argument through each function successively.
-- Returns the composed function.
local function comp(...)
  -- Capture magic `arg` variable.
  local fns = arg
  return function(v)
    -- Loop through all functions and transform value with each function
    -- successively. Feed transformed value to next function in line.
    return reduce(apply_to, v, fns)
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

-- Check if something is `nil`. Returns boolean.
local function is_something(thing)
  return thing ~= nil
end

-- Keep only values during reduction. All nil values will be ignored.
-- Note that `keep` is a transformation function. You can pass it a `step`
-- function and it will return a new `step` function that will only fold
-- over non-nil values.
-- Keep is an `xform` function. Use it on any `step` function.
local keep = filter(is_something)
exports.keep = keep

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

-- Given a transform function and a `predicate`, only use transformed steppper
-- for `input` that passes `predicate` test. All other inputs will be stepped
-- with the original step function. In contrast to `filter`, this means other
-- values will be untouched by `xform`, but will remain in reduction.
-- You can conceptualize this process as if we were branching the list,
-- transforming the contents of the branched list with `xform`, then merging
-- the result back into the original list.
-- Returns an xform function.
--
-- Example:
--
--     xf = branch_and_merge(map(add_one), is_number)
--     transduce(xf, step, 0, {1, "a", 2 "b", 3})
--
local function branch_and_merge(xform, predicate)
  return function (step)
    -- Create transformed step function
    local xformed_step = xform(step)
    return function (result, input)
      if predicate(input) then
        -- If input passes test, then step with transformed stepper.
        return xformed_step(result, input)
      else
        -- Otherwise step with original stepper.
        return step(result, input)
      end
    end
  end
end
exports.branch_and_merge = branch_and_merge

local function yield_indexed_reduction(i, v)
  local i = i + 1
  coroutine.yield(i, v)
  return i
end

-- Transform an iterator using a transformation function so that each value
-- yielded by the original iterator will be transformed using `xform`.
-- Returns a coroutine iterator.
--
-- Example:
--
--     ups = lazily(map(string.upper), {"a", "b", "c"})
--     for i, x in ups do print(i, x) end
--     > 1 "A"
--     > 2 "B"
--     > 3 "C"
local function lazily(xform, iter, state, at)
  return coroutine.wrap(function ()
    transduce(xform, yield_indexed_reduction, 0, iter, state, at)
  end)
end
exports.lazily = lazily

return exports
