-- simulate AceEvent
local CallbackHandler = {}
function CallbackHandler:Fire(eventname, ...)
    print("Fire:", eventname, ...)
    for _, fn in pairs(self.events[eventname]) do
        fn(eventname, ...)
    end
end
local events = { events = { test = {} } }
setmetatable(events, { __index = CallbackHandler })

function register(event, fn)
    table.insert(events.events[event], fn)
end

register("test", function(...)
    print("fn ...:", ...)
    local function cb(...)
        print("cb ...:", ...)
    end
    cb(select(2, ...))
end)

events:Fire("test", "ctx", "group")
