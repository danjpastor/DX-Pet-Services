local addonName, ns = ...

local Events = {
    listeners = {},
}
ns.Events = Events

local frame = CreateFrame("Frame")
Events.frame = frame

local function DispatchListener(listener, event, ...)
    local owner = listener.owner
    local callback = listener.callback

    if type(callback) == "string" then
        callback = owner and owner[callback]
    end
    if type(callback) ~= "function" then
        return
    end

    local args = { ... }
    local ok, err = xpcall(function()
        return callback(owner, event, unpack(args))
    end, geterrorhandler())
    if not ok and ns.db and ns.db.settings and ns.db.settings.debug then
        ns:Print("Event error:", event, err or "unknown")
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    local listeners = Events.listeners[event]
    if not listeners then
        return
    end

    for i = 1, #listeners do
        DispatchListener(listeners[i], event, ...)
    end
end)

-- Public API

function Events:Register(event, owner, callback)
    assert(type(event) == "string", "DX Pet Services: event name required")
    assert(type(owner) == "table", "DX Pet Services: event owner required")
    assert(type(callback) == "string" or type(callback) == "function", "DX Pet Services: callback required")

    if not self.listeners[event] then
        self.listeners[event] = {}
        frame:RegisterEvent(event)
    end

    self.listeners[event][#self.listeners[event] + 1] = {
        owner = owner,
        callback = callback,
    }
end

function Events:UnregisterOwner(owner)
    for event, listeners in pairs(self.listeners) do
        for i = #listeners, 1, -1 do
            if listeners[i].owner == owner then
                table.remove(listeners, i)
            end
        end

        if #listeners == 0 then
            self.listeners[event] = nil
            frame:UnregisterEvent(event)
        end
    end
end
