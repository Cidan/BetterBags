local events = {}
function events:RegisterMessage(event, callback)
    self[event] = callback
end
function events:SendMessage(event, ...)
    if self[event] then
        self[event]("some_event_name", ...)
    end
end
events:RegisterMessage("test", function(...)
    print("Received:", ...)
end)
events:SendMessage("test", "arg1", "arg2")
