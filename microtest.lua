--[[
Microtest
=========

Unit testing so small you can copy/paste it.

How to use:

    local microtest = require("microtest")
    local test, ok = microtest()

You can optionally provide your own custom loggers:

    local test, ok = microtest(log_pass, log_fail, log_info)

Microtest is syncronous because Lua is never async.
]]--


local function get_debug_msg(f)
  return debug.getinfo(3, 'S').short_src..":"..debug.getinfo(3, 'l').currentline
end

-- Create loggers using this higher-order factory.
local function logger(prefix)
  return function(msg)
    print(prefix .. msg)
  end
end

-- Create pass fail and info loggers
local microtest_log_fail = logger("[31m✘[0m ")
local microtest_log_pass = logger("[32m✔[0m ")
local microtest_log_info = logger("")

-- Microtest factory function
local function microtest(log_pass, log_fail, log_info)
  log_pass = log_pass or microtest_log_pass
  log_fail = log_fail or microtest_log_fail
  log_info = log_info or microtest_log_info

  -- Assert a value is truthy.
  local function ok(cond, msg)
    msg = msg or get_debug_msg()
    if cond then
      log_pass(msg)
    else
      log_fail(msg)
    end
  end

  -- Create a test suite.
  local function test(name, callback)
    log_info(name)
    local ok, err = pcall(callback)
    if not ok then
      log_fail(err)
    end
  end

  return test, ok
end
return microtest
