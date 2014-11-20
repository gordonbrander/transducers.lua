-- Create a table to store our exported values.
local exports = {}

local xf = require("transducers")
local transduce = xf.transduce

local function step_yield_input(_, v)
  -- Yield key, value pair. Note that this works with `filter` and `reject`
  -- because it is within the scope of the step function. Filtering `xform` will
  -- make sure this step function is not called for values that are filtered out.
  coroutine.yield(v)
end

-- Transform an iterator using a transformation function so that each value
-- yielded by the original iterator will be transformed using `xform`.
-- Returns a coroutine iterator.
--
-- Example:
--
--     ups = transform(map(string.upper), ipairs{"a", "b", "c"})
--     for v in ups do print(i, v) end
--     > "A"
--     > "B"
--     > "C"
local function transform(xform, iter, state, at)
  return coroutine.wrap(function ()
    transduce(xform, step_yield_input, nil, iter, state, at)
  end)
end
exports.transform = transform

local function append(t, v)
  table.insert(t, v)
  return t
end
exports.append = append

-- Collect all values from an iterator into a table.
-- Returns collected values.
-- Example:
--
--     local clone = collect(ipairs{1, 2, 3})
local function collect(iter, state, at)
  return reduce(append, {}, iter, state, at)
end
exports.collect = collect

local function xformer(xform_factory)
  return function(lambda, iter, state, at)
    return transform(xform_factory(lambda), iter, state, at)
  end
end

-- Map all values in an iterator. Returns an iterator of mapped values.
--
--     x = map(string.upper, ipairs{"a", "b", "c"})
--     for v in x do print(v) end
local map = xformer(xf.map)
exports.map = map

-- Filter values in an iterator. Returns an iterator of values that pass test.
--
--     x = filter(is_letter_a, ipairs{"a", "b", "c"})
--     for v in x do print(v) end
local filter = xformer(xf.filter)
exports.filter = filter

-- Reject values in an iterator. Returns an iterator of values that fail test.
--
--     x = reject(is_letter_a, ipairs{"a", "b", "c"})
--     for v in x do print(v) end
local reject = xformer(xf.reject)
exports.reject = reject

-- Take values in an iterator until predicate fails. Returns an iterator of
-- values before predicate fails.
--
--     x = take_while(is_lowercase, ipairs{"a", "B", "C"})
--     for v in x do print(v) end
local take_while = xformer(xf.take_while)
exports.take_while = take_while

-- Collapse adjacent values that are the same. Returns an iterator of values.
--
--     x = dedupe(ipairs{"a", "a", "b", "c"})
--     for v in x do print(v) end
local function dedupe(iter, state, at)
  return transform(xf.dedupe, iter, state, at)
end
exports.dedupe = dedupe

-- Transform an iterator of values into an iterator of reductions of that value.
-- Returns an iterator of values.
--
--     x = reductions(sum, 0, ipairs{1, 2, 3})
--     for v in x do print(v) end
local function reductions(step_reduction, seed, iter, state, at)
  return transform(xf.reductions(step_reduction, seed), iter, state, at)
end
exports.reductions = reductions

return exports
