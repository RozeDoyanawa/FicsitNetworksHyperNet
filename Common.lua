---@type table<string,EventData>
local eventHandlers = {}

local ADMIN_PORT = 10
local ARP = {}

function getAdminPort()
    return ADMIN_PORT
end

function getARP()
    return ARP
end



lineHeight = 1

itemForms = {
    Solid = 1,
    Fluid = 2,
    Gas = 3,
    Heat = 4
}
scriptInfo.resetting = false
scriptInfo.stopping = false

local SECOND_MILLIS = 1000
local MINUTE_MILLIS = 60 * SECOND_MILLIS
local HOUR_MILLIS = 60 * MINUTE_MILLIS


---@param timestamp number
---@param precision string|'"millis"'|'"all"'|'"hours"'|'"seconds"'|'"minutes"'|'"significant"'
function millisToTimeString(timestamp, precision)
    local hours = math.floor(timestamp / HOUR_MILLIS); timestamp = timestamp - hours * HOUR_MILLIS
    local minutes = math.floor(timestamp / MINUTE_MILLIS); timestamp = timestamp - hours * MINUTE_MILLIS
    local seconds = math.floor(timestamp / SECOND_MILLIS); timestamp = timestamp - hours * SECOND_MILLIS
    local ret = ""

    if hours > 0 or precision == "hours" then
        ret = ret .. tostring(hours) .. "h"
    end
    if precision == "hours" or (precision == "significant" and hours > 0) then
        return ret
    end
    if minutes > 0 or precision == "minutes" then
        ret = ret .. tostring(minutes) .. "m"
    end
    if precision == "minutes" or (precision == "significant" and minutes > 0) then
        return ret
    end
    if seconds > 0 or precision == "seconds" then
        ret = ret .. tostring(seconds) .. "s"
    end
    if precision == "seconds" or (precision == "significant" and seconds > 0)  then
        return ret
    end
    ret = ret .. tostring( timestamp) .. "ms"
    return ret
end


---@param s1 string
---@param s2 string
CASE_INSENSITIVE_COMPARATOR = function (s1, s2)
    local n1 = string.len(s1);
    local n2 = string.len(s2);
    local min = math.min(n1, n2);
    for i = 1,min do
        local c1 = string.sub(s1, i,i);
        local c2 = string.sub(s2, i,i);
        if (c1 ~= c2) then
            c1 = string.upper(c1);
            c2 = string.upper(c2);
            if (c1 ~= c2) then
                c1 = string.lower(c1);
                c2 = string.lower(c2);
                if (c1 ~= c2) then
                    -- No overflow because of numeric promotion
                    local ret = string.byte(c1) - string.byte(c2)
                    return ret;
                end
            end
        end
    end
    return n1 - n2;
end


---@class FluidType
---@field public name string @Fluid name
---@field public unpack string @Recipe name for unpacking
---@field public pack string @Recipe name for packing
---@field public packaged string @Packaged name of product
---@field public unpackCount number @Amount received on unpack
local FluidType = {}

---@param name string @Fluid name
---@param unpack string @Recipe name for unpacking
---@param pack string @Recipe name for packing
---@param packaged string @Packaged name of product
---@param unpackCount number @Amount received on unpack
---@return FluidType
function FluidType.new(name, unpack, pack, packaged, unpackCount)
    ---@type FluidType
    local c = {}
    c.name = name
    c.unpack = unpack
    c.pack = pack
    c.unpackCount = unpackCount
    c.packaged = packaged
    return c
end

---@type table<string, FluidType>
local fluidTypes = {
    ["Heavy Oil Residue"] = FluidType.new(
        "Heavy Oil Residue",
        "Roze Unpackage Heavy Oil Residue",
        "Packaged Heavy Oil Residue",
        "Packaged Heavy Oil Residue",
        2
    ),
    ["Water"] = FluidType.new(
        "Water",
        "Roze Unpackage Water",
        "Packaged Water",
        "Packaged Water",
        2
    ),
    ["Crude Oil"] = FluidType.new(
        "Crude Oil",
        "Roze Unpackage Oil",
        "Packaged Oil",
        "Packaged Oil",
        2
    ),
    ["Fuel"] = FluidType.new(
        "Fuel",
        "Roze Unpackage Fuel",
        "Packaged Fuel",
        "Packaged Fuel",
        2
    ),
    ["Liquid Biofuel"] = FluidType.new(
        "Liquid Biofuel",
        "Roze Unpackage Liquid Biofuel",
        "Packaged Liquid Biofuel",
        "Packaged Liquid Biofuel",
        2
    ),
    ["Alumina Solution"] = FluidType.new(
        "Alumina Solution",
        "Roze Unpackage Alumina Solution",
        "Packaged Alumina Solution",
        "Packaged Alumina Solution",
        2
    ),
}



function fixFluids()
    local packedFluids  = {}
    for _,v in pairs(fluidTypes) do
        packedFluids[v.packaged] = v
    end

    for _,v in pairs(packedFluids) do
        fluidTypes[_] = v
    end
end

fixFluids()


---@return table<string, FluidType>
function getFluidTypes()
    return fluidTypes
end



stackSize = {
    ["Iron Ingot"] = 100,
    ["Copper Ingot"] = 100,
    ["Caterium Ore"] = 100,
    ["Caterium Ingot"] = 100,
    ["Steel Ingot"] = 90,
    ["Iron Plate"] = 100,
    ["Iron Rod"] = 100,
    ["Steel Beam"] = 100,
    ["Steel Pipe"] = 100,
    ["Quickwire"] = 500,
    ["Wire"] = 500,
    ["Cable"] = 100,
    ["Screw"] = 500,
    ["Copper Sheet"] = 100,
    ["Heavy Modular Frame"] = 50,
    ["Modular Frame"] = 50,
    ["Concrete"] = 100,
    ["Silica"] = 100,
    ["Iron Ore"] = 100,
    ["Copper Ore"] = 100,
    ["Uranium"] = 100,
    ["Coal"] = 100,
    ["Petroleum Coke"] = 100,
    ["Bauxite"] = 100,
    ["Quartz"] = 100,
    ["Limestone"] = 100,
    ["Encased Industrial Beam"] = 100,
    ["Plastic"] = 100,
    ["Rubber"] = 100,
    ["Crystal Oscillator"] = 100,
    ["Circuit Board"] = 200,
    ["High-Speed Connector"] = 100,
    ["Supercomputer"] = 50,
    ["Computer"] = 50,
    ["AI Limiter"] = 100,
    ["Rotor"] = 100,
    ["Motor"] = 50,
    --["Photovoltaic Cell"] = 10,
    ["Biomass"] = 100,
    ["Reinforced Iron Plate"] = 100,
    ["Quartz Crystal"] = 100,
    ["Raw Quartz"] = 100,
    ["Stator"] = 50,
    ["Empty Canister"] = 100,
    ["Crude Oil"] = 50,
    ["Heavy Oil Residue"] = 50,
    ["Sulfuric Acid"] = 50,
    ["Water"] = 50,
    ["Black Powder"] = 50,
    ["Sulfur"] = 100,
    ["Carbon Mesh"] = 10,
    ["Carbon Dust"] = 10,
    ["Packaged Oil"] = 100,
    ["Packaged Water"] = 100,
    ["Packaged Heavy Oil Residue"] = 100,
    ["Packaged Fuel"] = 100,
    ["Packaged Alumina Solution"] = 100,
    ["Packaged Liquid Biofuel"] = 100,
    ["Packaged Sulfuric Acid"] = 100,
    ["Fuel"] = 100,
    ["Liquid Biofuel"] = 100,
    ["Alien Organs"] = 100,
    ["Alien Carapace"] = 100,
    ["Wood"] = 100,
    ["Mycelia"] = 100,
    ["Leaves"] = 500,
    ["Automated Wiring"] = 50,
    ["Smart Plating"] = 50,
    ["Modular Engine"] = 50,
    ["Versatile Framework"] = 50,
    ["Adaptive Control Unit"] = 50,
    ["Flower Petals"] = 200,
    ["Blue Power Slug"] = 50,
    ["Green Power Slug"] = 50,
    ["Yellow Power Slug"] = 50,
    ["Purple Power Slug"] = 50,
    ["FICSMAS Gift"] = 100,
    ["Polymer Resin"] = 200,
    ["Solid Biofuel"] = 200,
    ["Radio Control Unit"] = 50,
    ["Alumina Solution"] = 50,
    ["Aluminum Casing"] = 200,
    ["Aluminum Ingot"] = 100,
    ["Aluminum Scrap"] = 500,
    ["Aluminum Clad Sheet"] = 200,
    ["Alclad Aluminum Sheet"] = 200,
    ["Beacon"] = 100,
    ["Nobelisk"] = 50,
    ["Smokeless Powder"] = 100,
    ["Hog Remains"] = 50,
    ["Plasma Spitter Remains"] = 50,
}


function rgba(r,g,b,a)
    ---@type RGBAColor
    local col = {}
    col.R = r
    col.G = g
    col.B = b
    col.A = a
    return col
end
local defaultAlpha = 1

scriptInfo.systemColors = {
    Normal = rgba(0.5, 0.5, 0.5, defaultAlpha),
    Number = rgba(0.1, 0.1, 0.5, defaultAlpha),
    White = rgba(1,1,1,defaultAlpha),
    Black = rgba(0,0,0,defaultAlpha),
    Blue = rgba(0,0,0.5, defaultAlpha),
    Green = rgba(0, 0.57, 0, defaultAlpha),
    LightRed = rgba(1, 0, 0, defaultAlpha),
    Brown = rgba(0.5, 0,0,defaultAlpha),
    Purple = rgba(0.61, 0, 0.61, defaultAlpha),
    Orange = rgba(0.99, 0.5, 0, defaultAlpha),
    Yellow = rgba(1, 1, 0, defaultAlpha),
    LightGreen = rgba(0, 0.99, 0, defaultAlpha),
    Cyan = rgba(0, 0.57, 0.57, defaultAlpha),
    LightCyan = rgba(0, 1, 1, defaultAlpha),
    LightBlue = rgba(0.4, 0.4, 0.99, defaultAlpha),
    Pink = rgba(1, 0, 1, defaultAlpha),
    Grey = rgba(0.5, 0.5, 0.5, defaultAlpha),
    LightGrey = rgba(0.83, 0.83, 0.83, defaultAlpha),
}

scriptInfo.addresses = {
    InvMgr1 = "952B4E8C4EE276DBF4C2DF9C9057F888",
    InvMgr2 = "",
    BusMgr = "B35461CC45566F0ED431BC9CA6DB10B9",
    ProdMgr = "B0FB35C4420EA149FC17A29793CF765B",
    LogMgr = "3825B51947382D003E6ADB8FA817DB0F"
}


function wait(millisToWait)
    local millis = computer.millis()
    while computer.millis() - millis < millisToWait do
        computer.skip()
    end
end


---@class EventData
---@field public instance any @Instance reference
---@field public reference string|Actor @The reference that was listened for
---@field public callback fun(obj:any,signal:string,...) @Callback function
---@field public triggers table<string,fun(instance:any, ...:any)> @SubTriggers
---@field public doUnpack boolean @If set will unpack output parameters
local EventData




---@generic T:Object
---@param key any @The key to map this event to. Pass an Actor or a string
---@param instance T @The object that will be called as the self param to the callback function
---@param callback fun(self:T, event:string, parameters:string[], parameterOffset:number) @The callback function
---@param triggerHandlers table<string,fun(self:T, ...:any)> @SubTriggers
---@param doUnpack boolean|nil
function registerEvent(key, instance, callback, triggerHandlers, listen, doUnpack)
    computer.skip()
    ---@type EventData
    local evt = {
        instance = instance,
        reference = key,
        callback = callback,
        triggers = triggerHandlers,
        doUnpack = doUnpack
    }
    if key and key.hash then
        --print("Registering event by hash: " .. key.hash .. " for " .. tostring(key))
        eventHandlers[key.hash] = evt
    else
        eventHandlers[key] = evt
    end
    if listen ~= nil and listen == true then
        if key and key.hash then
            event.listen(key)
        else
            error("Cant listen to a null component or a non component object")
        end
    end
end

function enum(tbl)
    local length = #tbl
    for i = 1, length do
        local v = tbl[i]
        tbl[v] = i
    end

    return tbl
end

---@param numToRound number
---@param multiple number
---@return number
function roundUp(numToRound, multiple)

    if multiple == 0 then
        return numToRound;
    end

    local remainder = numToRound % multiple;
    if remainder == 0 then
        return numToRound;
    end

    return numToRound + multiple - remainder;
end

---@param numToRound number
---@param multiple number
---@return number
function roundDown(numToRound, multiple)

    if multiple == 0 then
        return numToRound;
    end

    local remainder = numToRound % multiple;
    if remainder == 0 then
        return numToRound;
    end

    return numToRound - remainder;
end


---@type table<number, NetworkHandler>
local networkHandlers = {}

---@param port number @Remote Host Port
---@param func fun(address:string, parameters:table<number,string>|table<string,string>, parameterOffset:number)
---@param subhandlers table<string, fun(address:string, parameters:table<number,string>|table<string, string>, parameterOffset:number) @List of command handlers for the given port
function networkHandler(port, func, subhandlers) -- function for creating a handler
    if func == nil then
        func = defNetworkHandler
    end
    networkHandlers[port] = {
        func = func,
        subhandlers = subhandlers,
    }
end

local REFRESH_DELAY = 60000


---@class ComponentReference<T>
---@generic T : FGBuildable
---@field public id string
---@field public object T
---@field public lastFetch number
ComponentReference = {}

---@generic T : FGBuildable
---@return T
function ComponentReference:get()
    if self.object == nil or computer.millis() - self.lastFetch > REFRESH_DELAY then
        self.object = component.proxy(self.id)
        self.lastFetch = computer.millis()
    end
    return self.object
end

---@generic T : FGBuildable
---@return ComponentReference<T>
function ComponentReference.new(networkID)
    ---@type ComponentReference
    local t = {
        id = networkID,
        lastFetch = 0,
        object = nil
    }
    setmetatable(t, ComponentReference)
    ComponentReference.__index = ComponentReference
    return t
end

---@generic T : FGBuildable
---@param stringID string
---@param clazz T
---@overload fun(stringID:string):ComponentReference<T>
---@return ComponentReference<T>
function createReference(stringID, clazz)
    --print("Create reference for " .. stringID)
    --local item = {
    --    id = stringID,
    --    object = nil,
    --    get = getReference,
    --    lastFetch = 0
    --}
    return ComponentReference.new(stringID, clazz)
end

--function getReference(reference)
--    if reference.object == nil or computer.millis() - reference.lastFetch > REFRESH_DELAY then
--        reference.object = component.proxy(reference.id)
--        reference.lastFetch = computer.millis()
--    end
--    return reference.object
--end
local oldmillis = computer.millis
function computer.millis()
    local a = oldmillis()
    local b = oldmillis()
    local c = math.abs( b - a )
    while c > 1 do
        local ts, ssf, dts = computer.magicTime()
        print( string.format( "%s : computer timer anomaly detected: %d ? %d ? %d", dts, a, b, c ) )
        a = oldmillis()
        b = oldmillis()
        c = math.abs( b - a )
    end
    --print("computer.millis(", a, c, ")")
    return a
end

function resetComputer()
    --print(debug.backtrace)
    --error(err)
    if scriptInfo.reset_handler ~= nil then
        scriptInfo.reset_handler()
    end

    scriptInfo.resetting = true
    if scriptInfo.network then
        scriptInfo.network:broadcast(10, "identifyReset")
        computer.skip()
    end
    rwarning("Computer reset issued!")
    local millis = computer.millis()
    event.clear()
    while computer.millis() - millis < math.random(1000,30000) do --
        event.pull(1)
        print("Reset wait loop ", tostring(computer.millis()), tostring(millis))
    end
    computer.skip()
    computer.reset()
end

function stopComputer()
    --print(debug.backtrace)
    --error(err)
    scriptInfo.stopping = true
    if scriptInfo.network then
        scriptInfo.network:broadcast(10, "identifyStop")
    end
    pcall(updateStatus)
    rwarning("Computer stop issued!")
    local millis = computer.millis()
    event.clear()
    while computer.millis() - millis < math.random(5000,10000) do --
        event.pull(1)
    end
    computer.skip()
    computer.stop()
end

function defNetworkHandler(self, address, parameters, parameterOffset)  -- Initiate handler for port 100
    local msg = parameters[parameterOffset] -- extract message identifier
    --print(msg)
    if msg and self.subhandlers[msg] then  -- if msg is not nil and we have a subhandler for it
        local handler = self.subhandlers[msg] -- put subhandler into local variable for convenience
        if parameters[parameterOffset + 1] == "json" then
            parameters = json.decode(parameters[parameterOffset + 2])
            handler(address, parameters, nil) -- call subhandler
        else
            handler(address, parameters, parameterOffset + 1) -- call subhandler
        end
    elseif not msg then -- no handler or nil message
        print ("No message identifier defined")
    else
        print ("No handler for " .. parameters[parameterOffset])
    end
end

if scriptInfo.network then
    print("Startup network")
    registerEvent(scriptInfo.network, null, function(instance, msg, params, po)
        local address = params[3] -- address param
        local port = params[4] -- port param
        --printArray(params, 2)
        --rdebug("Network message from " .. address .. " by port " .. port .. " msg " .. params[5])
        if networkHandlers[port] then -- check if we have a port handler
            computer.skip()
            networkHandlers[port]:func(address, params, 5)   -- call func with : OR with itself as first param
            computer.skip()
        else
            print ( "No handler for " .. tostring(port))
        end
    end)

    function sendIdentify(address)
        local info = {
            name = scriptInfo.name,
            fileSystemMonitor = scriptInfo.fileSystemMonitor,
            port = scriptInfo.port
        }
        if address ~= nil then
            scriptInfo.network:broadcast(ADMIN_PORT, "identifyResponse", "json", json.encode(info))
        else
            scriptInfo.network:broadcast(ADMIN_PORT, "identifyResponse", "json", json.encode(info))
        end
    end
    if scriptInfo.disableAdminListener == nil or disableAdminListener ~= true then
        networkHandler(ADMIN_PORT, defNetworkHandler, { -- table of message handlers
            ping = function(address, parameters, po)
                scriptInfo.network:send(address, ADMIN_PORT, "pong", parameters[po])
            end,
            pong = function(address, parameters, po)
                if ARP[address] then
                    local time = tonumber(parameters[po])
                    ARP[address].rtt = computer.millis() - time
                    ARP[address].lastPing = computer.millis()
                    ARP[address].online = true
                end
                --print("Pong from: " .. address)
            end,
            identifyError = function(address)
                if ARP[address] ~= nil then
                    ARP[address].errored = true
                    ARP[address].online = false
                end
            end,
            identifyReset = function(address)
                if ARP[address] ~= nil then
                    ARP[address].resetting = true
                end
            end,
            stop = function()
                if scriptInfo.preventStopAll == nil or not scriptInfo.preventStopAll then
                    stopComputer()
                end
            end,
            stopAll = function()
                if scriptInfo.preventStopAll == nil or not scriptInfo.preventStopAll then
                    stopComputer()
                end
            end,
            reset = function()
                resetComputer()
            end,
            resetAll = function()
                if scriptInfo.preventResetAll == nil or not scriptInfo.preventResetAll then
                    resetComputer()
                end
            end,
            identifyResponse = function(address, parameters)
                --print("ARP Response from " .. address)
                --printArray(parameters)
                local item = {
                    address = address,
                    name = parameters.name,
                    scriptInfo = parameters,
                    lastPing = computer.millis(),
                    identified = true,
                    online = true,
                    errored = false,
                    resetting = false,
                    rtt = -1
                }
                ARP[parameters.name] = item
                ARP[address] = item
            end,
            identify = function(address, parameters)
                --if address ~= scriptInfo.network.id then
                sendIdentify(address)
                --end
            end
        })
        scriptInfo.network:open(ADMIN_PORT) -- Administrative port
    end
end

function processEvent(pullResult)
    if pullResult[1] and pullResult[1] == "FileSystemUpdate" then
        if eventHandlers["FileSystemUpdate"] then
            eventHandlers["FileSystemUpdate"].callback(pullResult)
        end
        return
    end
    if pullResult[2] then
        print("E1")
        if pullResult[2].hash and eventHandlers[pullResult[2].hash] then
            print("E2")
            local v = eventHandlers[pullResult[2].hash]
            if v.triggers and v.triggers[pullResult[1]] then
                print("E3")
                local trigger = pullResult[1]
                table.remove(pullResult, 1)
                table.remove(pullResult, 1)
                v.triggers[trigger](v.instance, table.unpack(pullResult))
            elseif v.callback then
                print("E4")
                if v.doUnpack then
                    print("E5")
                    local trigger = pullResult[1]
                    table.remove(pullResult, 1)
                    table.remove(pullResult, 1)
                    v.callback(v.instance, trigger, table.unpack(pullResult))
                else
                    print("E6")
                    v.callback(v.instance, pullResult[1], pullResult, 2)
                end
            else
                if v.triggers then
                    for k,f in pairs(v.triggers) do
                        print("--" .. k .. " defined")
                    end
                end
                rerror("No handler or subhandler for " .. pullResult[2].hash .. "(" .. tostring(pullResult[2]) .. ") " .. ", by trigger " .. tostring(pullResult[1]))
            end
            computer.skip()
            return
        end
        error("No handler for " .. tostring(pullResult[2]) .. " by " .. pullResult[1])
    else
        if eventHandlers[pullResult[1]] then
            eventHandlers[pullResult[1]].callback(eventHandlers[pullResult[1]].instance, pullResult, 2)
        end
    end
    computer.skip()
end


---@class LinkedListItem
---@generic T
---@field public list LinkedList @Reference to this items parent list
---@field public value T @The value of this node
---@field public next LinkedListItem<T> @The next item in the list
---@field public previous LinkedListItem<T> @The previous item in the list
--@field public insert fun(value:any):LinkedListItem @Inserts an item after this in the list
--@field public delete fun() @Deletes this item from the list
--@field public print fun() @Prints this item and all its children
LinkedListItem = {}


---@class LinkedList
---@generic T
---@field public length number @The number of items in this list
---@field public first LinkedListItem<T> @The first item in the list, nil if no items
---@field public last LinkedListItem<T> @The last item in the list, nil if no items
LinkedList = {}


PeriodicTask = {}


---@param func fun(self:any)
---@param ref any
---@param minimumInterval number|nil
---@param comment string
---@param removeOnTrigger boolean
---@overload fun(func:fun(self:any), ref:any, minimumInterval:number|nil,comment:string):PeriodicTask
---@return PeriodicTask
function PeriodicTask.new(func, ref, minimumInterval, comment, removeOnTrigger)
    if removeOnTrigger == nil then
        removeOnTrigger = false
    end
    ---@type PeriodicTask
    local q = {}
    q.ref = ref
    q.func = func
    q.lastExecution = computer.millis()
    q.comment = comment
    q.removeOnTrigger = removeOnTrigger
    if minimumInterval == nil then
        q.minimumInterval = 0
    else
        q.minimumInterval = minimumInterval
    end
    setmetatable(q, PeriodicTask)
    PeriodicTask.__index = PeriodicTask
    return q
end

--function LinkedListItem:insert(value)
--    local self = after.list
--    if after then
--        if after.next then
--            after.next.prev = t
--            t.next = after.next
--        else
--            self.last = t
--        end
--
--        t.prev = after
--        after.next = t
--    elseif not self.first then
--        -- this is the first node
--        self.first = t
--        self.last = t
--    end
--    self.length = self.length + 1
--end

function LinkedListItem:delete()
    local list = self.list
    if self.next then
        if self.prev then
            self.next.prev = self.prev
            self.prev.next = self.next
        else
            -- this was the first node
            self.next.prev = nil
            list.first = self.next
        end
    elseif self.prev then
        -- this was the last node
        self.prev.next = nil
        list.last = self.prev
    else
        -- this was the only node
        list.first = nil
        list.last = nil
    end
    self.next = nil
    self.prev = nil
    list.length = list.length - 1
end

function LinkedListItem:print()
    for k,v in pairs(self) do
        print(tostring(k).." = " ..tostring(v))
    end
end

---@return LinkedListItem
---@generic T
---@param value T
function LinkedList:push(value)
    local t = self:createItem(value)
    if self.last then
        self.last.next = t
        t.prev = self.last
        self.last = t
    else
        -- this is the first node
        self.first = t
        self.last = t
    end
    self.length = self.length + 1
    return t
end

---@return LinkedListItem
function LinkedList:shift(value)
    local t = self:createItem(value)
    if self.first then
        t.next = self.first
        self.first.prev = t
        self.first = t
    else
        -- this is the first node
        self.first = t
        self.last = t
    end
    self.length = self.length + 1
    return t
end

---@return LinkedListItem
function LinkedList:pop()
    if not self.last then return end
    local ret = self.last

    if ret.prev then
        ret.prev.next = nil
        self.last = ret.prev
        ret.prev = nil
    else
        -- this was the only node
        self.first = nil
        self.last = nil
    end

    self.length = self.length - 1
    return ret
end

function LinkedList:clear()
    self.first = nil
    self.last = nil
    self.length = 0
end

function LinkedList:print(depth)
    local item = self.first
    print("Linked list... {")
    local index = 1
    while item ~= nil do
        print("Item " .. index .. "={")
        printArray(item.value, depth)
        print("}")
        item = item.next
    end
    print("}")
end

---@private
---@generic T
---@param value T @The value to initialize the item with
---@return LinkedListItem
function LinkedList:createItem(value)
    return LinkedListItem.new( self, value)
end

---@private
---@generic T
---@param value T @The value to initialize the item with
---@return LinkedListItem
function LinkedListItem:new(value)
    ---@type LinkedListItem
    local t = {
        list = self,
        value = value,
        next = nil,
        previous = nil,
    }
    setmetatable(t, LinkedListItem)
    LinkedListItem.__index = LinkedListItem
    return t
end


---@generic T
---@param clazz T
---@return LinkedList<T>
function LinkedList.new(clazz)
    ---@type LinkedList
    local list = {
        first = nil,
        last = nil,
        length = 0,
        clazz = clazz
    }
    setmetatable(list, LinkedList)
    LinkedList.__index = LinkedList
    return list
end

---@generic T
---@return LinkedList<T>
---@deprecated
function createLinkedList()
    return LinkedList.new()
end

---@return table<string,string>
function parseOutputs(param)
    local p = explode(":", param)
    local ret = {}
    for _,v in pairs(p) do
        local name = string.sub(v,1,1)
        local value = string.sub(v, 2)
        ret[name] = value
    end
    return ret
end

---@return table<string,string>
---@param data string
function parseParams(data)
    local mode = 0
    local escape = false
    ---@type table<string,string>
    local out = {}
    local key = ""
    local temp = ""
    for i = 1,string.len(data),1 do
        local c = string.sub(data, i, i)
        if c == "\\" and not escape then
            escape = true
        elseif escape then
            temp = temp .. c
        elseif c == "=" and mode == 0 then
            key = temp
            temp = ""
            mode = 1
        elseif c == "|" and mode == 0 then
            out[temp] = true
            temp =  ""
        elseif c == "|" and mode == 1 then
            out[key] = temp;
            key = ""
            temp = ""
            mode = 0
        else
            temp = temp .. c
        end
    end
    if temp ~= "" then
        if mode == 0 then
            out[temp] = true
        elseif mode == 1 then
            out[key] = temp
        end
    end

    return out
end


---@type LinkedList
---@generic T:PeriodicTask
local periodicStuff = LinkedList.new(PeriodicTask)

---@param task PeriodicTask
function schedulePeriodicTask(task)
    if task == nil then
        return
    end
    periodicStuff:push(task)
end

function rmessage(message)
    if scriptInfo.network then
        scriptInfo.network:broadcast(101, "msg", message, scriptInfo.name)
        print(message)
    else
        print(message)
    end
end
function rerror(message)
    if scriptInfo.network then
        scriptInfo.network:broadcast(10, "identifyError")
        scriptInfo.network:broadcast(101, "error", message, scriptInfo.name)
    else
        print(message)
    end
end
function rwarning(message)
    if scriptInfo.network then
        scriptInfo.network:broadcast(101, "warning", message, scriptInfo.name)
    else
        print(message)
    end
end
function rdebug(message)
    if scriptInfo.debugging and scriptInfo.debugging == true then
        if scriptInfo.network then
            scriptInfo.network:broadcast(101, "debug", message, scriptInfo.name)
            print(message)
        else
            print(message)
        end
    end
end


function initBrightnessPanel()
    if scriptInfo.screen ~= nil then
        local panelBrightness = component.proxy(component.findComponent(scriptInfo.name .. "_BrightnessPanel")[1])
        local dispBrightness = panelBrightness:getXModule(1)
        local knobBrightness = panelBrightness:getXModule(0)
        local data = {
            disp = dispBrightness,
            knob = knobBrightness,
        }

        registerEvent(knobBrightness, data, function(self, msg, params)
            data.disp:setText(tostring(params[3]))
            scriptInfo.screen:setTransparency(params[3] / 100)
        end, nil, true)

        dispBrightness:setText(tostring(knobBrightness.value))
        scriptInfo.screen:setTransparency(knobBrightness.value / 100)
    end
end

---@param gpu GPU_T1_C
---@param a RGBAColor
function rsSetColorA(gpu, a)
    gpu:setForeground(a.R,a.G,a.B,a.A)
end

---@param GPU_T1_C
function rsClear(gpu)
    gpu:fill(0,0,scriptInfo.screenWidth,scriptInfo.screenHeight," ")
end


---@param x number X Position
---@param y number Y Position
---@param colwidth number Width to advance by if y exceeds screen height
function rsadvanceY(x, y, colwidth)
    y = y + lineHeight
    if y > scriptInfo.screenHeight - 1 then
        y = 0
        x = x + colwidth
    end
    computer.skip()
    return x, y
end

---@param div string @Divisor
---@param str string @String to be split
---@return string[]|boolean
function explode(div,str) -- credit: http://richard.warburton.it
    if (div=='') then return false end
    local pos,arr = 0,{}
    -- for each divider found
    for st,sp in function() return string.find(str,div,pos,true) end do
        table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
        pos = sp + 1 -- Jump past current divider
    end
    table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
    return arr
end



-- all of these functions return their result and a boolean
-- to notify the caller if the string was even changed

-- pad the left side

---@param s string @The string to pad
---@param l number @How long to pad the string to
---@param c string @The character to pad with
---@return string, boolean @The new padded string and if the new string is equal to the old string
function lpad(s, l, c)
    local res = string.rep(c or ' ', l - #s) .. s

    return res, res ~= s
end

-- pad the right side
---@param s string @The string to pad
---@param l number @How long to pad the string to
---@param c string @The character to pad with
---@return string, boolean @The new padded string and if the new string is equal to the old string
function rpad(s, l, c)
    local res = s .. string.rep(c or ' ', l - #s)

    return res, res ~= s
end

-- pad on both sides (centering with left justification)
---@param s string @The string to pad
---@param l number @How long to pad the string to
---@param c string @The character to pad with
---@return string, boolean @The new padded string and if the new string is equal to the old string
function pad(s, l, c)
    c = c or ' '

    local res1, stat1 = rpad(s,    (l / 2) + #s, c) -- pad to half-length + the length of s
    local res2, stat2 = lpad(res1,  l,           c) -- right-pad our left-padded string to the full length

    return res2, stat1 or stat2
end


---@overload fun(arr)
function printArray(arr, depth)
    ArrayPrinter.new(arr, depth):printToConsole()
end


---@class OutputStream
local OutputStream = {}

---@class FileOutputStream:OutputStream
---@field private outputFile file @Internal holder for the open file
---@field private fileName string @Internal comment for the name of the open file
local FileOutputStream = {}

---Constructs a new output stream to write to the console
function OutputStream.new()
    ---@type OutputStream
    local obj = {}
    setmetatable(obj, OutputStream)
    OutputStream.__index = OutputStream
    return obj
end

---Constructs a new output stream to the given file
---@param fileName string @The name of the file to write to
function FileOutputStream.new(fileName)
    local file = filesystem.open(fileName, "w")
    ---@type FileOutputStream
    local obj = {
        outputFile = file,
        fileName = fileName
    }
    setmetatable(obj, FileOutputStream)
    FileOutputStream.__index = FileOutputStream
    return obj
end

---@param text string
function OutputStream:write(text)
    print(text)
end

---@param text string
function FileOutputStream:write(text)
    self.outputFile:write(text .. "\n")
end

---Closes the current open stream
function FileOutputStream:close()
    self.outputFile:close()
end


---@class ArrayPrinter
---@field private targetDepth number
---@field private history table<table,boolean>
---@field private highIndex number @The highest index reached for references
---@field private array any @The array to work on
---@field private output OutputStream @Internally used to hold the output writer
---public
ArrayPrinter = {}


---Creates a new ArrayPrinter working on the given array
---@param array table @The array to work on
---@param depth number @The maximum depth in the table to work to
function ArrayPrinter.new(array, depth)
    if depth == nil then
        depth = -1
    end
    ---@type ArrayPrinter
    local obj = {
        targetDepth = depth,
        highIndex = 1,
        history = {},
        array = array,
    }
    setmetatable(obj, ArrayPrinter)
    ArrayPrinter.__index = ArrayPrinter
    return obj
end

---Internal worker function, do not call this directly, there will be no output to write to
---@param arr table<any, any>|any[]|string @The current table object
---@param level number @The current level to print to
---@private
function ArrayPrinter:_print(arr, level)
    if self.array == nil then
        print "[nil]"
        return
    end
    local spaces1 = rpad("", (level) * 2, " ")
    local spaces = rpad("", (level + 1) * 2, " ")
    self.output:write(spaces1.."Array<" .. tostring(self.highIndex) .. ">{")
    self.history[arr] = self.highIndex
    self.highIndex = self.highIndex + 1
    level = level + 1
    if type(arr) == "table" then
        for k,v in pairs(arr) do
            if v == nil then
                self.output:write(spaces..tostring(k).."=nil")
            elseif type(v) == "string" then
                self.output:write(spaces..tostring(k) .. "='"..v.."'")
            elseif type(v) == "table" then
                if self.history[v] ~= nil then
                    self.output:write(spaces .. tostring(k) .. " = <Reference#" .. tostring(self.history[v]) .. ">")
                else
                    if self.targetDepth < 0 or level < self.targetDepth then
                        self.output:write(spaces..tostring(k) .. "=")
                        self:_print(v, level + 1)
                    else
                        self.output:write(spaces..tostring(k) .. "= <limited by detph>")
                    end
                end
            else
                self.output:write(spaces.. tostring(k) .. "="..tostring(v))
            end
        end
    elseif type(arr) == "string" then
        self.output:write(arr)
    end
    self.output:write(spaces1.."}")
end

---Internal function to reset the print data
---@private
function ArrayPrinter:reset()
    self.history = {}
    self.highIndex = 1
end

---Prints the content of the bound array to the console
function ArrayPrinter:printToConsole()
    self:reset()
    self.output = OutputStream.new()
    self:_print(self.array, 0)
end

---Prints the content of the bound array to the given file
function ArrayPrinter:printToFile(fileName)
    self:reset()
    self.output = FileOutputStream.new(fileName)
    self:_print(self.array, 0)
    self.output:close()
end


function printArrayToFile(fileName, arr, depth)
    ArrayPrinter.new(arr, depth):printToFile(fileName)
end

function initGPU()
    local gpu = computer.getPCIDevices(classes.GPU_T1_C)[1]
    print("GPU", gpu)
    local screen = scriptInfo.screen
    print("Screen", screen)
    if screen ~= nil and gpu ~= nil then
        scriptInfo.gpu = gpu
        gpu:bindScreen(screen)
        gpu:setBackground(0,0,0,0)
        gpu:setsize (scriptInfo.screenWidth, scriptInfo.screenHeight)
        local screenW,screenH = gpu:getSize()
        gpu:fill(0,0,screenW,screenH," ")
        gpu:setForeground(1,1,1,1)
        print("Screen init done")
        gpu:flush()
    end
end

---@param fileName string
---@param data string
function dumpDataToFile(fileName, data)
    local output = FileOutputStream.new(fileName)
    output:write(data)
    output:close()
end


--printArrayToFile("fluidTypes_init.txt", fluidTypes)

--function setCommandLabelText(panel, index, text, vertical, color)
--	if vertical == nil then
--		vertical = true
--	end
--	if color == nil then
--		color = rgba(1, 1, 1, 1)
--	end
--	panel:setForeground(index, color[1], color[2], color[3])
--	panel:setText(index, text, vertical)
--end

---@param module MCP_Mod_2Pos_Switch_C|MCP_Mod_3Pos_Switch_C|PushbuttonModule|MushroomPushbuttonModule|ModuleButton|IndicatorModule
---@param color RGBAColor
function setModuleColor(module, color)
    module:setColor(color.R, color.G, color.B, color.A)
end

---@param ref MCP_Mod_Encoder_C @Actor reference
---@param callback fun(self:MCP_Mod_Encoder_C, change:number)
function initModularEncoder(ref, callback)
    ---@type table<string, fun(self:any, ...:any)>
    local triggers = {valueChanged = callback}
    registerEvent(ref, ref, nil, triggers)
    event.listen(ref)
end

---@param ref MCP_Mod_Potentiometer_C|MCP_Mod_PotWNum_C @Actor reference
---@param callback fun(self:MCP_Mod_Potentiometer_C, value:number)
---@param min number
---@param max number
---@return number
function initModularPotentiometer(ref, callback, min, max)
    ---@type table<string, fun(self:any, ...:any)>
    local triggers = {valueChanged = callback}
    ref.min = min
    ref.max = max
    registerEvent(ref, ref, nil, triggers)
    event.listen(ref)
    return ref.value
end

---@param ref PushbuttonModule|MushroomPushbuttonModule|ModuleButton @Actor reference
---@param callback fun(self:PushbuttonModule|MushroomPushbuttonModule|ModuleButton) @Actor Event Callback Function
---@param defColor RGBAColor @The new color, nil if no change
---@param subscribe boolean @If true, will subscribe the ref to event.listen()
function initModularButton(ref, callback, defColor)
    if defColor ~= nil then
        setModuleColor(ref, defColor)
    end
    ---@type table<string, fun(self:any, ...:any)>
    local triggers = {Trigger = callback}
	registerEvent(ref, ref, nil, triggers)
    event.listen(ref)
end

---@param ref MCP_Mod_3Pos_Switch_C|MCP_Mod_2Pos_Switch_C @Actor reference
---@param callback fun(self:MCP_Mod_3Pos_Switch_C|MCP_Mod_2Pos_Switch_C, state:number)
---@param defColor RGBAColor @Default Color of this button
function initModularSwitch(ref, callback, defColor)
    if defColor ~= nil then
        setModuleColor(ref, defColor)
    end
    ---@type table<string, fun(self:any, ...:any)>
    local triggers = {ChangeState = callback}
    registerEvent(ref, ref, nil, triggers)
    event.listen(ref)
end


function commonError(err)

end

function computer.getGPUs()
    return computer.getPCIDevices(findClass("GPU_T1_C"))
end


function coroutine.xpcall(co)
    local output = {coroutine.resume(co)}
    if output[1] == false then
        return false, output[2], debug.traceback(co)
    end
    return table.unpack(output)
end

DOUBLE_LINE_BOX = {"╔", "═", "╗", "║", " ", "║", "╚", "═", "╝"}

function generateSquareFrame(subset, width, height)
    local box = {}
    box[#box + 1] = subset[1] .. string.rep(subset[2], width - 2) .. subset[3]
    local space = string.rep(subset[5], width - 2)
    for i = 1, height - 2 do
        box[#box + 1] = subset[4] .. space .. subset[6]
    end
    box[#box + 1] = subset[7] .. string.rep(subset[8], width - 2) .. subset[9]
    return box;
end

function rsprintSquareFrame(gpu, subset, x, y, width, height)
    local box = generateSquareFrame(subset, width, height)
    for _,v in pairs(box) do
        gpu:setText(x, y, v)
        y = y + 1
    end
end

local commonMainCounter = 0
--error("TestError")

--error("test")
local timeout = 1


---@param timeoutLong number
---@param timeoutShort number
---@param seldomCallback fun()
function commonMain(timeoutLong, timeoutShort, seldomCallback)
    ---@type LinkedListItem
    local periodicTask

    while true do
        local result = {event.pull(timeout) }
        if result[1] then
            timeout = timeoutShort
        else
            timeout = timeoutLong
        end
        --print(result[1])
        processEvent(result)

        if periodicTask == nil then
            periodicTask = periodicStuff.first
        end
        if periodicTask ~= nil then
            ---@type PeriodicTask
            local item = periodicTask.value
            ---@type number
            local m = computer.millis()
            if item.func == nil then
                if item.comment ~= nil then
                    error("Function in periodic task " .. item.comment .. " is null")
                else
                    error("Function in periodic task without comment is null")
                end
            end
            local next = periodicTask.next
            --print("Millis: " , m);
            if item.minimumInterval == 0 or m - item.lastExecution >= item.minimumInterval then
                --print("Task timeout: " , m, item.lastExecution, m-item.lastExecution, ">=", item.minimumInterval)
                item.lastExecution = computer.millis()
                if item.func(item.ref) then
                    timeout = timeoutShort
                end
                if item.removeOnTrigger then
                    periodicTask:delete()
                end
            end
            periodicTask = next
            --print(periodicTask.value.ref.stock.resource)
        end

        if timeout > 0 or seldomCounter == 0 then
            if seldomCallback ~= nil then
                seldomCallback()
            end
            commonMainCounter = 1000
        else
            commonMainCounter = commonMainCounter - 1
        end
    end
end

---@type table<string,any>
persistentProperties = {}
---@type string
persistentPropertiesFile = nil

function initProperties(filename)
    persistentPropertiesFile = filename
    readProperties()
end

function writeProperties()
    if persistentPropertiesFile ~= nil then
        ---@type file
        local f = filesystem.open(persistentPropertiesFile, "w")
        f:write(json.encode(persistentProperties))
        f:close()
    end

end

function readProperties()
    if persistentPropertiesFile ~= nil then
        ---@type file
        local f = filesystem.open(persistentPropertiesFile, "r")
        local data = ""
        local temp = ""
        local maxRead = 1024
        while true do
            temp = f:read(maxRead)
            if not temp then
                break
            end
            data = data .. temp
        end
        if string.len(data) > 0 then
            persistentProperties = json.decode(data)
            return true
        end
    end
    return false
end

local errorCount = 0

LAST_ERROR_TRACE = nil

function commonInit()
    --event.clear()
    if scriptInfo.network and scriptInfo.port then
        scriptInfo.network:open(scriptInfo.port)
        event.listen(scriptInfo.network)
        scriptInfo.network:broadcast(ADMIN_PORT, "identify")
    else
        print ("No such adapter")
    end

    initGPU()
    if scriptInfo.fileSystemMonitor then
        print("Reboot on FileSystemUpdate is Enabled")
        registerEvent("FileSystemUpdate", nil, function(pullRequest)
			--printArray(pullRequest, 2)
            if pullRequest[4] and pullRequest[4] == "/Common.lua" or pullRequest[4] == "/Program.lua" then
                resetComputer()
            end
        end)
        registerEvent(computer.getInstance(), computer.getInstance(), function(instance, event)
            print("ComputerInstanceEvent", instance, event)
        end, nil, true, false)
    end
    local programFile = "Program.lua"
    if scriptInfo.mainProgram ~= nil then
        programFile = scriptInfo.mainProgram;
    end

    filesystem.doFile(programFile)


    --local co = coroutine.create(main)
    --local ret = {coroutine.resume(co)}
    --print(coroutine.status(co))
    --printArray(ret, 1)
    --if not errorFree then
    --    rerror("Error in main; "..tostring(value).."   "..debug.traceback(co))
    --    computer.skip()
    --    resetComputer()
    --else
    --    print(coroutine.status(co))
    --    print(errorFree)
    --    print(value)
    --end


    --local status,err,LAST_ERROR_TRACE = main()

    --local routine = coroutine.create(main)
    --coroutine.resume(routine)


    local status, err = xpcall(main, function(err)
        LAST_ERROR_TRACE = debug.traceback()
    end)

    --local status, err, LAST_ERROR_TRACE = coroutine.xpcall(routine)

    --print(err)
    --printArray(LAST_ERROR_TRACE)
    --print(status)
    if not status and err then
        if errorCount > 0 then
            computer.stop()
        end
        print(LAST_ERROR_TRACE);
        print(debug.traceback());
        print(err.message);
        print(err.trace);
        --for _, v in pairs(err.trace) do
         --   print(json.encode(v))
        --end
        errorCount = errorCount + 1
        if scriptInfo.error_handler ~= nil then
            scriptInfo.error_handler()
        end
        errorCount = errorCount - 1
        if scriptInfo.preventRestartError == nil or scriptInfo.preventRestartError == false then
            --resetComputer()
        end
    end

    print("Done")

end

