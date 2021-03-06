--- Module which is responsible for dispatching events with expectations
--
-- *Dependencies:* `expectations`, `events`
--
-- *Globals:* `expectations`, `events`, `res`, `c`, `e`, `exp`, `pool`
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

expectations = require('expectations')
events = require('events')

--- Type which is responsible for dispatching events with expectations
-- @type EventDispatcher
local Dispatcher = {}
local mt = { __index = { } }

--- Construct instance of EventDispatcher type
-- @treturn EventDispatcher Constructed instance
function Dispatcher.EventDispatcher()
  local res =
  {
    --- Pool of events level 1
    _pool1 = { },
    --- Pool of events level 2
    _pool2 = { },
    --- Pool of events level 3
    _pool3 = { },
    --- Pre event handler
    preEventHandler = nil,
    --- Post event handler
    postEventHandler = nil
  }
  setmetatable(res, mt)
  return res
end

--- Get Handler
-- @tparam Connection conn Mobile/HMI connection
-- @tparam Event ev Event
-- @treturn table Handler
function mt.__index:GetHandler(conn, ev)
  res = self._pool3[conn][ev] or
  self._pool2[conn][ev] or
  self._pool1[conn][ev]
  return res
end

--- Find handler for event
-- @tparam Connection obj Mobile/HMI connection
-- @tparam Event data Event
-- @treturn table Handler
function mt.__index:FindHandler(obj, data)

  -- Visit all event pools and find matching event
  local function findInPool(pool, data)
    for e, h in pairs(pool) do
      if e:matches(data) then
        return h
      end
    end
    return nil
  end

  return findInPool(self._pool3[obj], data) or
      findInPool(self._pool2[obj], data) or
      findInPool(self._pool1[obj], data)
end

--- Set handler for pre event
-- @tparam function func Pre event handler.
function mt.__index:OnPreEvent(func)
  self.preEventHandler = func
end

--- Set handler for post event
-- @tparam function func Post event handler.
function mt.__index:OnPostEvent(func)
  self.postEventHandler = func
end

--- Validate all expectations
function mt.__index:validateAll()

  local function iter(pool)
    for e, exp in pairs(pool) do
      exp:validate()
    end
  end

  for c, pool in pairs(self._pool3) do iter(pool) end
  for c, pool in pairs(self._pool2) do iter(pool) end
  for c, pool in pairs(self._pool1) do iter(pool) end
end

--- Subscribe on connection's [[OnInputData]] signal
-- @tparam Connection connection Mobile/HMI connection
function mt.__index:AddConnection(connection)
  local this = self
  self._pool1[connection] = { }
  self._pool2[connection] = { }
  self._pool3[connection] = { }
  connection:OnConnected(function (self)
      if this.preEventHandler then
        this.preEventHandler(events.connectedEvent)
      end
      exp = this:GetHandler(self, events.connectedEvent)
      if exp then
        exp.occurences = exp.occurences + 1
        exp:Action()
        this:validateAll()
      end
      if this.postEventHandler then
        this.postEventHandler(events.connectedEvent)
      end
    end)
  connection:OnDisconnected(function (self)
      if this.preEventHandler then
        this.preEventHandler(events.disconnectedEvent)
      end
      exp = this:GetHandler(self, events.disconnectedEvent)
      if exp then
        exp.occurences = exp.occurences + 1
        exp:Action()
        this:validateAll()
      end
      if this.postEventHandler then
        this.postEventHandler(events.disconnectedEvent)
      end
    end)
  connection:OnInputData(function (self, data)
      this:RaiseEvent(self, data)
    end)
end

--- Raise event
-- @tparam Connection connection Mobile/HMI connection
-- @tparam table data Data for rise event
function mt.__index:RaiseEvent(connection, data)
  if self.preEventHandler and data then
    self.preEventHandler(data)
  end
  exp = self:FindHandler(connection, data)
  if exp then
    exp.occurences = exp.occurences + 1
    if data then
      if exp.verifyData then
        for k, v in pairs(exp.verifyData) do
            v(exp, data)
            if (exp.status == expectations.FAILED) then
                break
            end
        end
      end
      exp:Action(data)
    end
    self:validateAll()
  end
  if self.postEventHandler then
    self.postEventHandler(data)
  end
end

--- Add event with expectation to pools
-- @tparam Connection connection Mobile/HMI connection
-- @tparam Event event Event to be addded
-- @tparam Expectation expectation Expectation for added event
function mt.__index:AddEvent(connection, event, expectation)
  if event.level == 3 then
    self._pool3[connection][event] = expectation
  elseif event.level == 2 then
    self._pool2[connection][event] = expectation
  elseif event.level == 1 then
    self._pool1[connection][event] = expectation
  end
end

--- Remove event with expectation from pools
-- @tparam Connection connection Mobile/HMI connection
-- @tparam Event event Event to be removed
function mt.__index:RemoveEvent(connection, event)
  self._pool3[connection][event] = nil
  self._pool2[connection][event] = nil
  self._pool1[connection][event] = nil
end

--- Remove all events with expectation from pools
function mt.__index:ClearEvents()
  for c, pool in pairs(self._pool3) do self._pool3[c] = { } end
  for c, pool in pairs(self._pool2) do self._pool2[c] = { } end
  for c, pool in pairs(self._pool1) do self._pool1[c] = { } end
end

return Dispatcher
