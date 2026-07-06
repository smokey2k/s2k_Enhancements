-- CallbackHandler-1.0 compatibility implementation.
-- It provides the public callback API required by LibDataBroker-1.1.
-- A deliberately low minor version lets a newer embedded Ace3 copy upgrade it.
local MAJOR, MINOR = "CallbackHandler-1.0", 1
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)
if not CallbackHandler then return end

local type, pairs, next, select = type, pairs, next, select
local error, tostring = error, tostring
local unpack = unpack

local function SafeCall(func, ...)
    if securecallfunction then
        return securecallfunction(func, ...)
    end
    local ok, err = pcall(func, ...)
    if not ok then
        geterrorhandler()(err)
    end
end

function CallbackHandler.New(_self, target, registerName, unregisterName, unregisterAllName)
    target = target or {}
    registerName = registerName or "RegisterCallback"
    unregisterName = unregisterName or "UnregisterCallback"
    if unregisterAllName == nil then unregisterAllName = "UnregisterAllCallbacks" end

    local events = {}
    local registry = { events = events }

    function registry:Fire(eventName, ...)
        local handlers = events[eventName]
        if not handlers or not next(handlers) then return end

        -- Snapshot the handlers so callbacks can safely register/unregister while firing.
        local snapshot = {}
        for owner, func in pairs(handlers) do
            snapshot[#snapshot + 1] = { owner, func }
        end
        for i = 1, #snapshot do
            local entry = snapshot[i]
            if handlers[entry[1]] == entry[2] then
                SafeCall(entry[2], eventName, ...)
            end
        end
    end

    target[registerName] = function(owner, eventName, method, ...)
        if type(eventName) ~= "string" then
            error("Usage: " .. registerName .. "(eventname, method[, arg]): 'eventname' - string expected.", 2)
        end
        method = method or eventName
        if type(method) ~= "string" and type(method) ~= "function" then
            error("Usage: " .. registerName .. "(eventname, method): method must be a string or function.", 2)
        end

        local extraCount = select("#", ...)
        local extraArg = extraCount > 0 and select(1, ...) or nil
        local callback

        if type(method) == "string" then
            if type(owner) ~= "table" or type(owner[method]) ~= "function" then
                error("Callback method '" .. tostring(method) .. "' was not found on the registering object.", 2)
            end
            if extraCount > 0 then
                callback = function(event, ...)
                    owner[method](owner, extraArg, event, ...)
                end
            else
                callback = function(event, ...)
                    owner[method](owner, event, ...)
                end
            end
        else
            if extraCount > 0 then
                callback = function(event, ...)
                    method(extraArg, event, ...)
                end
            else
                callback = method
            end
        end

        local handlers = events[eventName]
        local wasEmpty = not handlers or not next(handlers)
        if not handlers then
            handlers = {}
            events[eventName] = handlers
        end
        handlers[owner] = callback

        if wasEmpty and registry.OnUsed then
            registry.OnUsed(registry, target, eventName)
        end
    end

    target[unregisterName] = function(owner, eventName)
        if type(eventName) ~= "string" then
            error("Usage: " .. unregisterName .. "(eventname): 'eventname' - string expected.", 2)
        end
        local handlers = events[eventName]
        if handlers and handlers[owner] then
            handlers[owner] = nil
            if registry.OnUnused and not next(handlers) then
                registry.OnUnused(registry, target, eventName)
            end
        end
    end

    if unregisterAllName then
        target[unregisterAllName] = function(...)
            local count = select("#", ...)
            if count < 1 then
                error("Usage: " .. unregisterAllName .. "([owner]): missing owner.", 2)
            end
            for i = 1, count do
                local owner = select(i, ...)
                for eventName, handlers in pairs(events) do
                    if handlers[owner] then
                        handlers[owner] = nil
                        if registry.OnUnused and not next(handlers) then
                            registry.OnUnused(registry, target, eventName)
                        end
                    end
                end
            end
        end
    end

    return registry
end
