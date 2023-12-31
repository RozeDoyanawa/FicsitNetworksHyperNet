

local SignIcons = {
    Stop = 341,
    Exit = 348,
    UpArrow = 334,
    DownArrow = 329,
}

---@type string[]
local components = {}
---@type table<string,table<string,string>>
local componentNickData = {}


---@type table<string,TransportNode>
local transportNodes = {}


--##########################################################################################
--##############################                             ###############################
--##############################     Transport Node Gate     ###############################
--##############################                             ###############################
--##########################################################################################

---@class PassthroughGate
---@field name string
---@field parent TransportNode
---@field next PassthroughGate
---@field metric number
---@field index number
---@field gateComp ComponentReference<CircuitSwitch>
---@field gate table<string,string>
local PassthroughGate = {
    parent = nil,
    next = nil,
}

---@param name string
---@param index string
---@return PassthroughGate
function PassthroughGate.new(name, index)
    ---@type PassthroughGate
    local obj = {
        name = name,
        metric = 0
    }
    obj.gate = getHyperNetObject(name, "gate", index)
    obj.index = tonumber(index)
    obj.gateComp = createReference(obj.gate.id, CircuitSwitch)
    obj.parent = getNode(name)
    obj.next = nil

    if obj.gate.next == "auto" then
        local sourcePipeData = getHyperNetObject(obj.name, "pipe", tostring(obj.index))
        if sourcePipeData == nil then
            error("No such pipe object : " .. obj.name .. " for gate " .. obj.index)
        end
        ---@type Build_PipeHyperStart_C
        local sourcePipe = component.proxy(sourcePipeData.id)
        --print(sourcePipe)
        local connectors = sourcePipe:getPipeConnectors()
        if connectors ~= nil then
            for __index, value in pairs(connectors) do
                --print(__index, value)
            end
        else
            print("Connector nil");
        end
        local result = enumeratePipe(connectors[1], 60, 0)
        obj.pipeRoute = result
        --print("Result: " , result)
        local remoteFound = false
        if result ~= nil and #result > 0 then
            --printArrayToFile("result" .. name .. "x" .. index ..".txt", result, 5)
            --print(tostring(result:getType().name))
            local comp = result[#result]
            if comp:getType().name == "Build_PipeHyperStart_C" then
                if comp.nick ~= nil then
                    local nick = comp.nick
                    if string.sub( nick,0, 9) == "HyperNet " then
                        nick = string.sub(nick, 10)
                        local params = parseParams(nick)
                        --printArrayToFile("ParamsTemp.txt", params)
                        if params.node ~= nil then
                            obj.gate.next = params.node
                            obj.metric = calculatePipeLengthFromActorList(result)
                            local locations = {}
                            for _,v in pairs(result) do
                                table.insert(locations, {x = v.location.x, y = v.location.y, z = v.location.z})
                            end
                            dumpDataToFile("tubedata/pipe_" .. obj.gate.index .. "-at-" .. name .. "_to-" .. obj.gate.next .. ".json", json.encode(locations))
                            remoteFound = true
                        end
                    else
                        print("Nick not match at end of pipe",nick)
                        computer.stop()
                    end
                else
                    print("Nick null at end of pipe", comp)
                    --computer.stop()
                end
            else
                print("Type missmatch at end of pipe", comp:getType().name)
                --computer.stop()
            end
        end
        if remoteFound == false then
            if obj.metric ~= 0 then
                error("Metrric?")
            end
            obj.next = nil
            obj.gate.next = nil
        end
    end
    setmetatable(obj, PassthroughGate)
    PassthroughGate.__index = PassthroughGate
    obj:setEnabled(false)
    return obj
end

---@param connector PipeConnectionBase
---@param maxDepth number The deepest this method will search for the end of the pipe. Simply a guard method during testing
---@param level number Used internally to check maximum depth
---@return Actor
---@overload fun(connector:PipeConnectionBase, maxDepth:number):Actor
---@overload fun(connector:PipeConnectionBase):Actor  Traverses the pipe with no maximum depth, in case of endless loop, game will likely freeze
function traversePipe(connector, maxDepth, level)
    if maxDepth == nil then
        maxDepth = 0
    end
    if level == nil then
        level = 1
    end
    if maxDepth > 0 and level >= maxDepth then
        computer.stop()
        return nil
    end
    --print(connector, connector.hash, connector.owner, connector.owner.hash)
    local target = connector:getConnection()
    if target == nil then
        return connector.owner
    end
    local targetOwner = target.owner
    local ownerConnectors = targetOwner:getPipeConnectors()
    for _,ownerConnector in pairs(ownerConnectors) do
        if ownerConnector ~= target then
            local r = traversePipe(ownerConnector, maxDepth, level + 1)
            if r ~= nil then
                return r
            end
        end
    end

    return targetOwner
end

---@param startObject Build_PipeHyperStart_C
function calculatePipeLengthFromEntrance(startObject)
    local connectors = startObject:getPipeConnectors()
    local result = enumeratePipe(connectors[1], 60, 0)
    local lastObject = startObject
    local length = 0
    for _, v in pairs(result) do
        length = length + ((lastObject.x - v.x) ^ 2 + (lastObject.y - v.y) ^ 2 + (lastObject.z - v.z) ^ 2)^(1/2)
    end
    return length
end


---@param actors Actor[]
---@return number
function calculatePipeLengthFromActorList(actors)
    local lastObject = actors[1]
    local length = 0
    local L = lastObject.location
    for _, v in pairs(actors) do
        local N = v.location
        length = length + math.sqrt((L.x - N.x) ^ 2 + (L.y - N.y) ^ 2 + (L.z - N.z) ^ 2)
        L = N
    end
    return length
end

---@param connector PipeConnectionBase
---@param maxDepth number The deepest this method will search for the end of the pipe. Simply a guard method during testing
---@param level number Used internally to check maximum depth
---@return Actor[]
---@overload fun(connector:PipeConnectionBase, maxDepth:number):Actor[]
---@overload fun(connector:PipeConnectionBase):Actor[]  Traverses the pipe with no maximum depth, in case of endless loop, game will likely freeze
function enumeratePipe(connector, maxDepth, level)
    if maxDepth == nil then
        maxDepth = 0
    end
    if level == nil then
        level = 1
    end
    if maxDepth > 0 and level >= maxDepth then
        computer.stop()
        return nil
    end
    --print(connector, connector.hash, connector.owner, connector.owner.hash)
    local target = connector:getConnection()
    if target == nil then
        local list = {}
        table.insert(list, connector.owner)
        return list
    end
    local targetOwner = target.owner
    local ownerConnectors = targetOwner:getPipeConnectors()
    ---@param ownerConnector PipeConnectionBase
    for _,ownerConnector in pairs(ownerConnectors) do
        if ownerConnector ~= target then
            local r = enumeratePipe(ownerConnector, maxDepth, level + 1)
            if r ~= nil then
                table.insert(r, 1, targetOwner)
                return r
            end
        end
    end

    ---@type Actor[]
    local list = {}
    table.insert(list, targetOwner)
    return list
end

function PassthroughGate:updateDestination()
    if self.gate.next ~= nil then
        local remNode = getNode(self.gate.next)
        if remNode == nil then
            self.next = nil;
            return
        end
        self.next = remNode:getGateFrom(self.name)
        if self.next == nil then
            error(self.parent.name .. " gate ".. self.index .. " nil next")
        end
        --if self.parent.name == "RBEntJ" and self.index == 3 then
        --    printArray(self.gate)
        --    print(remNode)
        --    print(self.next)
        --    error()
        --end
        if self.metric == 0 then
            ---@type CircuitSwitch
            local remComp = remNode.exitComp:get()
            local remLoc = remComp.location

            ---@type CircuitSwitch
            local locComp = self.parent.exitComp:get()
            local locLoc = locComp.location

            self.metric = math.sqrt((remLoc.x - locLoc.x) ^ 2 + (remLoc.y - locLoc.y) ^ 2 + (remLoc.z - locLoc.z) ^ 2)
        end
        --print(self.gate.next , " is not null for gate ", self.gate.index, " in node ", self.name, " next = ", self.next)
        --error("")
    else
        --print("Clearing " .. self.index .. " for node " .. self.parent.name)
        --if self.index == 0 and self.name == "RBEntJ" then
        --    error()
        --end
        self.next = nil
    end
end

---@param state boolean
function PassthroughGate:setEnabled(state)
    --print("Setting state of gate " ,self.gate.index, "of node" , self.parent.name, "to", state)
    ---@type CircuitSwitch
    local v = self.gateComp:get()
    v:setIsSwitchOn(state)
end

---@class TransportState : number
local TransportState = {
    Free = 0,
    Occupied = 1,
    WaitingTraveler = 2,
    WaitingExit = 3,
}

--##########################################################################################
--##############################                             ###############################
--##############################       Transport Node        ###############################
--##############################                             ###############################
--##########################################################################################


---@class TransportNode
---@field passthrough table<number,PassthroughGate>
---@field name string
---@field entranceComp ComponentReference
---@field exitComp ComponentReference
---@field panel SmallTransportPanel
---@field ui LargeTransportUI
---@field tower HyperNetSignalTower
---@field sign SignFormat
---@field junction boolean
---@field location Point3D
---@field activePath TravelNode[]
local TransportNode = {
}

---@param name string
---@return TransportNode
function TransportNode.new(name)
    ---@type TransportNode
    local obj = {
        name = name,
        caption = "Node " .. name,
        passthrough = {  },
        entranceComp = nil,
        exitComp = nil,
        state = TransportState.Free,
        panel = nil,
        junction = true,
        activePath = nil,
    }
    setmetatable(obj, TransportNode)
    TransportNode.__index = TransportNode
    return obj
end

---@param state boolean
function TransportNode:setAliveFlash(state)
    if self.tower ~= nil then
        self.tower:setAlive(state);
    end
end

---@param path TravelNode[]
function TransportNode:setActivePath(path)
    self.activePath = path
    if path ~= nil and #path > 0 then
        local srcNode = path[1]
        local dstNode = path[#path]
        if srcNode ~= nil and srcNode.node.sign ~= nil then
            srcNode.node.sign:setIcon(SignIcons.UpArrow)
            srcNode.node.sign:setText(path[1].node.caption .. "\n ->" .. dstNode.node.caption .. "(" .. tostring(#path - 1) .. ")")
        end
        if dstNode ~= nil and  dstNode.node.sign ~= nil then
            dstNode.node.sign:setIcon(SignIcons.Exit)
        end
    else
        self.sign:setIcon(SignIcons.Stop)
        self.sign:setText(self.caption)
    end
end

---@param state number
function TransportNode:setState(state)
    self.state = state
    if self.panel ~= nil then
        if state == TransportState.Free or state == TransportState.WaitingTraveler then
            self.panel:setTravelEnabled(true)
        else
            self.panel:setTravelEnabled(false)
        end
    end
    if self.tower ~= nil then
        self.tower:update()
    end
end

---@param success boolean
---@param connector PipeConnectionBase
---@param pipe Build_PipeHyper_C
function TransportNode:transferFunction(event, success)
    print("transferFunction(" , event , success, ")")
    if event == "PlayerEntered" then
        self:setEntryEnabled(false)
        if self.activePath ~= nil then
            print("Entry @ node " .. self.name)
            for _, value in pairs(self.activePath) do
                value.node:setState(TransportState.Occupied)
            end
            self.activePath[#self.activePath].node:setState(TransportState.WaitingExit)
            self:setActivePath(nil)
        else
            print("Invalid path for entry @ node " .. self.name)
        end
    elseif event == "PlayerExited" then
        if self.activePath ~= nil then
            print("Exit @ node " .. self.name)
            for _, value in pairs(self.activePath) do
                value.node:setState(TransportState.Free)
            end
            self:setActivePath(nil)
        else
            print("Invalid path for exit @ node " .. self.name)
        end
    else
        print("Invalid event @ node " .. self.name.. ", event is " .. event)
    end
end

---@param state boolean
function TransportNode:setEntryEnabled(state)
    --print("Setting state of entry of node " , self.name, "to" ,state)
    ---@type CircuitSwitch
    local v = self.entranceComp:get()
    v:setIsSwitchOn(state):await()
end

---@param state boolean
function TransportNode:setExitEnabled(state)
    --print("Setting state of exit of node " , self.name, "to" ,state)
    ---@type CircuitSwitch
    local v = self.exitComp:get()
    v:setIsSwitchOn(state):await()
end

---@param state boolean
function TransportNode:closeAll()
    if not self.junction then
        if self.entranceComp ~= nil then
            self:setEntryEnabled(false)
        end
        if self.exitComp ~= nil then
            self:setExitEnabled(false)
        end
    end
    if self.panel ~= nil then
        self.panel:setSelectedDestinationIndex(self.panel.destinationIndex)
    end
    if self.sign ~= nil then
        self.sign:setIcon(SignIcons.Stop)
        self.sign:setText(self.caption)
    end
    self:setState(TransportState.Free)
    for _,v in pairs(self.passthrough) do
        v:setEnabled(false)
    end
end

---@param name string
---@return PassthroughGate
function TransportNode:getGateFrom(name)
    --print("getGateFrom(", self.name, ",", name, ")")
    for k,v in pairs(self.passthrough) do
        --print("->", "(", v.gate.next, "~= nil):", (v.gate.next ~= nil), "(" , v.gate.next, "==", name, "):", v.gate.next == name )
        if v.gate.next ~= nil and v.gate.next == name then
            return v
        end
    end
    return nil
end
---@param destination string Node name of the destination node
function TransportNode:openTravel(destination)

    local path = findPath(self.name, destination, 20)
    --print("Path=",path)
    local pn = {}
    if path ~= nil and #path > 0 then
        path[1].node:setEntryEnabled(true)
        path[1].node:setActivePath(path)
        path[1].node:setState(TransportState.WaitingTraveler)
        ---@type TravelNode
        local dst
        for _, v in pairs(path) do
            if v.gate == nil then
                v.node:setExitEnabled(true)
                v.node:setActivePath(path)
                for _,v2 in pairs(v.node.passthrough) do
                    v2:setEnabled(false)
                end
                if v.node.state == TransportState.Free then
                    v.node:setState(TransportState.Occupied)
                end
            else
                if v.node.exitComp ~= nil then
                    v.node:setExitEnabled(false)
                end
                for _,v2 in pairs(v.node.passthrough) do
                    v2:setEnabled(v.gate == v2)
                end
                if v.node.state == TransportState.Free then
                    v.node:setState(TransportState.Occupied)
                end
            end

            if v.gate ~= nil then
                pn[_] = v.node.name .. " : " .. v.gate.index
            else
                pn[_] = v.node.name .. " : E"
            end
            dst = v
        end

        if self.panel ~= nil then
            self.panel.btnTravel:setColor(0, 1, 0, 1)

            ---@param self SmallTransportPanel
            schedulePeriodicTask(PeriodicTask.new(function(self)
                if self.parent.state == TransportState.WaitingTraveler then
                    if self.parent.activePath ~= nil then
                        for _, v in pairs(self.parent.activePath) do
                            if v.node.state == TransportState.Occupied then
                                v.node:setState(TransportState.Free)
                            end
                        end
                    end
                    self.parent:setEntryEnabled(false)
                    self.parent:setActivePath(nil)
                    self.parent:setState(TransportState.Free)
                end
            end, self.panel, 5000, "Tube not taken", true))
        end
    else
        if self.panel ~= nil then
            self.panel.btnTravel:setColor(1,0,0,1)
            ---@param self SmallTransportPanel
            schedulePeriodicTask(PeriodicTask.new(function(self)
                self:setTravelEnabled(self.travelEnabled)
            end, self.panel, 2000, "Reset button color", true))
        end
    end

    printArrayToFile("TravelPath.txt", pn, 10)
    --local cur = path
    --while cur ~= nil do
    --    if cur.next ~= nil then
    --        cur.node.passthrough[tonumber(cur.gate.gate.index)]:setEnabled(true)
    --    else
    --        cur.node:setExitEnabled(true)
    --    end
    --    cur = cur.next
    --end
    --if path~= nil then
    --    path.node:setEntryEnabled(true)
    --end
end



--##########################################################################################
--##############################                             ###############################
--##############################   Vanilla Sign Management   ###############################
--##############################                             ###############################
--##########################################################################################

---@class SignFormat
---@field comp ComponentReference<Build_StandaloneWidgetSign_Small_C>
---@field dataCache PrefabSignData
local SignFormat = {}

---@param nodeName string
---@return SignFormat
function SignFormat.new(nodeName)
    local data = getHyperNetObject(nodeName, "sign")
    if data == nil then
        return nil
    end
    ---@type SignFormat
    local obj = {
        comp = ComponentReference.new(data.id),
        --next = next,
    }
    setmetatable(obj, SignFormat)
    SignFormat.__index = SignFormat

    return obj
end

---@param iconNumber number
---@param iconElement string
---@overload fun(iconNumber:number)
function SignFormat:setIcon(iconNumber, iconElement)
    ---@type Build_StandaloneWidgetSign_Small_C
    local comp = self.comp:get()
    if iconElement == nil then
        iconElement = "Icon"
    end

    if self.dataCache == nil then
        self.dataCache = comp:getPrefabSignData()
    end
    self.dataCache:setIconElement(iconElement, iconNumber)

    comp:setPrefabSignData(self.dataCache)
end

---@param text string
---@param textElement string
---@overload fun(text:string)
function SignFormat:setText(text, textElement)
    ---@type Build_StandaloneWidgetSign_Small_C
    local comp = self.comp:get()
    if textElement == nil then
        textElement = "Name"
    end

    if self.dataCache == nil then
        self.dataCache = comp:getPrefabSignData()
    end
    self.dataCache:setTextElement(textElement, text)

    comp:setPrefabSignData(self.dataCache)
end




--##########################################################################################
--################################                        ##################################
--################################       Travel Node      ##################################
--################################                        ##################################
--##########################################################################################

---@class TravelNode
---@field next TravelNode
---@field returnGate PassthroughGate
---@field previous TravelNode
---@field gate PassthroughGate
---@field node TransportNode
local TravelNode = {}

---@param node TransportNode
--@field next TravelNode
---@field gate PassthroughGate
---@overload fun(node):TravelNode
---@return TravelNode
function TravelNode.new(node, gate)
    ---@type TravelNode
    local obj = {
        node = node,
        gate = gate,
        --next = next,
    }
    setmetatable(obj, TravelNode)
    TravelNode.__index = TravelNode
    return obj
end

---@param nodeName string The source node
---@param history string[] Visited nodes
---@param maxDepth number Max recursions
---@param level number Internally used to track depth
---@overload fun(nodeName:string, destination:string):string[]
---@overload fun(nodeName:string, destination:string, maxDepth:number):string[]
---@overload fun(nodeName:string, destination:string, maxDepth:number, nodes:string[]):string[]
---@return TravelNode[]
function findPath(nodeName, destination, maxDepth, history, level)
    if level == nil then
        level = 1
    end
    if maxDepth > 0 and level > maxDepth then
        return
    end
    if history == nil then
        history = {}
    end
    --print("findPath(nodeName=", nodeName, ",destination=", destination, ",maxDepth=", maxDepth, ",nodes=", nodes, ",#nodes=", count(nodes), ",level=", level, ")")
    if history[nodeName] == nil then
        --print("nodes[", nodeName, "] is nil")
        local node = getNode(nodeName)
        if node.state ~= TransportState.Free then
            return nil
        end
        if nodeName == destination then
            ---@type TravelNode[]
            local t = {}
            table.insert(t, 1, TravelNode.new(getNode(nodeName)))
            return t
        end
        history[nodeName] = node.name
        --printArray(nodes)
        for _,v in pairs(node.passthrough) do
            --print("traversing gate " , v.gate.index)
            if v.next ~= nil then
                ---@type TravelNode[]
                local t
                if v.next.parent.name == destination and v.next.parent.state == TransportState.Free then
                    t = {}
                    --print " -> End Reached"
                    table.insert(t, 1, TravelNode.new(node, v))
                    table.insert(t, TravelNode.new(v.next.parent))
                    return t
                end
            end
        end
        local paths = {}
        local minMetric = nil
        local retIndex = 0
        --local lengths = {}
        for k,v in pairs(node.passthrough) do
            --print("traversing gate " , v.gate.index)
            if v.next ~= nil then
                ---@type TravelNode[]
                local t = findPath(v.next.parent.name, destination, maxDepth, history, level + 1)
                if t ~= nil then
                    table.insert(t, 1, TravelNode.new(node, v))
                    local metric = 0
                    for _,v2 in pairs(t) do
                        if v2.gate ~= nil then
                            metric = metric + v2.gate.metric
                        end
                    end
                    if minMetric == nil or minMetric > metric then
                        minMetric = metric
                        retIndex = k
                    end
                    paths[k] = t
                end
            end
        end
        return paths[retIndex]
        --printArray(nodes)
    end
    return nil
end


--##########################################################################################
--################################                         #################################
--################################  Small Transport Panel  #################################
--################################                         #################################
--##########################################################################################

---@class DestinationItem
---@field nodeName string
---@field distance number
---@field accessible boolean
local DestinationItem = {}


---@class SmallTransportPanel
---@field panelObj ComponentReference<SizeableModulePanel>
---@field entranceSign SignFormat
---@field encDestination EncoderModule
---@field txtDestination LargeMicroDisplayModule
---@field txtDistance LargeMicroDisplayModule
---@field btnTravel PushbuttonModule|MushroomPushbuttonModule
---@field parent TransportNode
---@field destinationIndex number
---@field destinations DestinationItem[]
local SmallTransportPanel = {
}


function getClassName(obj)
    local v = tostring(obj)
    local _start = "Object<"
    local _end = ">"
    if string.len(v) > string.len(_start) + string.len(_end) then
        if string.sub(v, 0, string.len(_start)) == _start  then

        end
    end
end

---@return SmallTransportPanel
---@param name string
function SmallTransportPanel.new(name)
    local panel = getHyperNetObject(name, "controls")
    if panel == nil then
        return nil
    end
    ---@type SmallTransportPanel
    local obj = {
        panelObj = createReference(panel.id),
        pot = nil,
        button = nil,
        display = nil,
        parent = nil,
        destinations = {},
        destinationIndex = 0,
        travelEnabled = false,
    }
    setmetatable(obj, SmallTransportPanel)
    SmallTransportPanel.__index = SmallTransportPanel

    obj.parent = getNode(name)


    ---@type SizeableModulePanel
    local panelComp = obj.panelObj:get()
    local typeInfo = ""
    local btn = nil
    local txt1 = nil
    local txt2 = nil
    local enc = nil
    if panelComp ~= nil then
        local debugMatrix = ""
        local debugTypes = ""
        local width = math.abs(panelComp.width);
        local height = math.abs(panelComp.height);

        if panel.variant ~= nil then
            debugTypes = debugTypes .. "Variant: "  .. panel.variant .. "\r\n"
        end
        if width == 1 then
            typeInfo = "Y:"
        elseif height == 1 then
            typeInfo = "X:"
        end

        --print(tostring(height) .. "x" .. tostring(width))
        debugMatrix = debugMatrix .. "┌" .. rpad("", width * 6 - 1, "─").."┐\r\n"
        local lastClass = nil
        local reverse = false
        for y=0,height - 1,1 do
            debugMatrix = debugMatrix .. "│"
            for x=0,width - 1,1 do
                local t = panelComp:getModule(x,y);
                if t ~= nil then
                    debugMatrix = debugMatrix .. lpad(tostring(x), 2, " ") .. "x" .. rpad(tostring(y), 2, " ")
                    debugTypes = debugTypes .. tostring(x) .. "x" .. tostring(y).. ": " .. tostring(t) .. "\r\n"
                    local class = t:getType().name
                    if class == "MushroomPushbuttonModule" or class == "PushbuttonModule" then
                        btn = t
                        if enc == nil then
                            reverse = true
                        end
                        --typeInfo = typeInfo .. "Mb"
                    elseif class == "LargeMicroDisplayModule" then
                        if class ~= lastClass then
                            if txt1 == nil then
                                txt1 = t
                            elseif txt2 == nil then
                                txt2 = t
                            end
                            lastClass = class
                        else
                            lastClass = nil
                        end
                        --typeInfo = typeInfo .. "Ld"
                    elseif class == "EncoderModule" then
                        enc = t
                        --typeInfo = typeInfo .. "En"
                    end
                else
                    debugMatrix = debugMatrix .. "     "
                end
                debugMatrix = debugMatrix .. "│"
            end
            debugMatrix = debugMatrix .. "\r\n"
        end
        debugTypes = debugTypes .. "enc=" .. tostring(enc) .. "\r\n"
        debugTypes = debugTypes .. "txt1=" .. tostring(txt1) .. "\r\n"
        debugTypes = debugTypes .. "txt2=" .. tostring(txt2) .. "\r\n"
        debugTypes = debugTypes .. "btn=" .. tostring(btn) .. "\r\n"
        if reverse then
            local t = txt1
            txt1 = txt2
            txt2 = t
        end
        debugMatrix = debugMatrix .. "└" .. rpad("", width * 6 - 1, "─").."┘\r\n"
        debugTypes = debugTypes .. "reversed=" .. tostring(reverse) .. "\r\n"
        --print(debugMatrix .. "\r\n" .. debugTypes )
        printArrayToFile("panels/panel-" .. obj.parent.name .. ".txt", debugMatrix .. "\r\n\r\n" .. debugTypes .. "\r\n\r\nTypeinfo: " .. typeInfo)
    end

    obj.txtDistance = txt2
    obj.txtDestination = txt1
    obj.btnTravel = btn
    obj.encDestination = enc
    if obj.txtDistance~= nil then
        obj.txtDistance:setColor(0.2, 0.2, 0.6, 0.5)
    end
    obj.txtDestination:setColor(0.6, 0.6, 0.6, 0.5)

    initModularEncoder(obj.encDestination, function(self, change)
        obj:setSelectedDestinationIndex(obj.destinationIndex + change)
    end)

    --print(obj.enc)
    --print(obj.display)
    --print(obj.button)

    initModularButton(obj.btnTravel, function(self)
        obj:onTravelButton()
    end, rgba(0.1,0.1,0.1, 0))

    --print(obj.button)

    return obj
end



function SmallTransportPanel:onTravelButton()
    print("openTravel(from=", self.parent.name , ")")
    if self.travelEnabled and self.parent.state == TransportState.Free then
        local destination = self.destinations[self.destinationIndex]
        print("self.destinationIndex=" , self.destinationIndex)
        if destination == nil then
            printArray(self.destinations, 2)
            error("Destination is nil")
        end
        self.parent:openTravel(destination.nodeName)
    else
        if not self.travelEnabled then
            print("Travel not possible cause travel is disabled on node")
        else
            print("Travel not possible cause node is not free")
        end
    end
end

---@param state boolean
function SmallTransportPanel:setTravelEnabled(state)
    self.travelEnabled = state
    if state and self.parent.state == TransportState.Free then
        self.btnTravel:setColor(0, 1, 0, 0)
    elseif state then
        self.btnTravel:setColor(1, 1, 0, 0)
    else
        self.btnTravel:setColor(1, 0, 0, 0)
    end
end

---@param index number
function SmallTransportPanel:setSelectedDestinationIndex(index)
    local destinationCount = #self.destinations
    if destinationCount > 0 then
        if index < 1 then
            index = 1
        elseif index >= destinationCount then
            index = #self.destinations
        end
        local destinationNode = getNode(self.destinations[index].nodeName)
        self.destinationIndex = index
        self.txtDestination:setText(destinationNode.caption)

        self.txtDestination:setColor(0.8, 0.8, 0.4, 0.5)
        if self.txtDistance ~= nil then
            local path = findPath(self.parent.name, self.destinations[index].nodeName, 20)
            local metric = 0
            if path ~= nil and #path > 0 then
                for _, v in pairs(path) do
                    if v.gate ~= nil then
                        metric = metric + v.gate.metric
                    end
                end
            end
            local unit = "m"
            metric = metric / 100
            if metric > 10000 then
                metric = metric / 10000
                unit = "mil"
            elseif metric > 1000 then
                metric = metric / 1000
                unit = "km"
            end
            self.txtDistance:setText(string.format("%.0f", metric) .. unit)
        end
        self:setTravelEnabled(true)
    else
        self.txtDestination:setText("No Destinations")
        self.txtDestination:setColor(0.4, 0.4, 0.4, 0.5)
        self:setTravelEnabled(false)
    end
end

function SmallTransportPanel:refreshDestinations()
    --print("Updating destinations for node ", self.parent.name)
    local selfLocation = self.parent.location
    local accessibleNodes = getAccessibleNodes(self.parent.name, 20)
    self.destinations = {}
    for _,v in pairs(accessibleNodes) do
        if v.accessible and v.nodeName ~= self.parent.name then
            local nodeL = getNode(v.nodeName).location
            v.distance = math.sqrt((nodeL.x - selfLocation.x) ^ 2 + (nodeL.y - selfLocation.y) ^ 2 + (nodeL.z - selfLocation.z) ^ 2)
            ---@type DestinationItem
            table.insert(self.destinations, v)
        end
    end
    ---@param a DestinationItem
    ---@param b DestinationItem
    usort(self.destinations, function(a,b)
        if a.distance > b.distance then
            return -1
        elseif a.distance < b.distance then
            return 1
        end
        return 0
    end)

    if self.parent.name == "4" and #self.destinations <= 4 then
        --printArray(self.destinations, 2)
        --error()
        --computer.stop()
    end
    --if self.parent.name == "4" then
    --    printArrayToFile("Destinations.txt", self.destinations, 2)
    --    computer.stop()
    --end
    self:setSelectedDestinationIndex(self.destinationIndex)
end





--##########################################################################################
--##################################                    ####################################
--################################## Large Transport UI ####################################
--##################################                    ####################################
--##########################################################################################

---@class LargeTransportUI
---@field panelObj ComponentReference<MCP_6Point_C>
---@field encNavigate EncoderModule|Actor
---@field display ComponentReference<Build_RSS_1x2_C>
---@field btnTravel MushroomPushbuttonModule|Actor
---@field btnReset PushbuttonModule|Actor
---@field parent TransportNode
---@field destinationIndex number
---@field destinations string[]
local LargeTransportUI = {
}

---@param node TransportNode
function LargeTransportUI.new(node)
    local panel = getHyperNetObject(node.name, "ui.controls")
    local sign = getHyperNetObject(node.name, "ui")
    if panel == nil or sign == nil then
        return nil
    end
    ---@type LargeTransportUI
    local obj = {
        panelObj = createReference(panel.id),
        pot = nil,
        button = nil,
        display = createReference(sign.id),
        parent = nil,
        destinations = {},
        destinationIndex = 0,
        travelEnabled = false,
    }
    setmetatable(obj, LargeTransportUI)
    LargeTransportUI.__index = LargeTransportUI

    obj.parent = node

    ---@type MCP_6Point_C
    local panelComp = obj.panelObj:get()
    obj.btnTravel = panelComp:getModule(0, 0)
    obj.encNavigate = panelComp:getModule(4, 0)
    obj.btnReset = panelComp:getModule(5, 0)

    --print(obj.encNavigate)

    initModularEncoder(obj.encNavigate, function(self, change)
        obj:setSelectedDestinationIndex(obj.destinationIndex + change)
    end)

    --print(obj.enc)
    --print(obj.display)
    --print(obj.button)

    initModularButton(obj.btnTravel, function(self)
        obj:onTravelButton()
    end, rgba(0.1,0.1,0.1, 0))

    --print(obj.button)

    return obj
end

function LargeTransportUI:onTravelButton()
    print("openTravel(from=", self.parent.name , ")")
    if scriptInfo.errorFlag ~= nil and scriptInfo.errorFlag then
        scriptInfo.errorFlag = false
        computer.reset()
    else
        if self.travelEnabled and self.parent.state == TransportState.Free then
            local destination = self.destinations[self.destinationIndex]
            print("self.destinationIndex=" , self.destinationIndex)
            if destination == nil then
                printArray(self.destinations, 2)
                error("Destination is nil")
            end
            self.parent:openTravel(destination)
        else
            if not self.travelEnabled then
                print("Travel not possible cause travel is disabled on node")
            else
                print("Travel not possible cause node is not free")
            end
        end
    end
end


function LargeTransportUI:update()
    ---@type RSSBuildableSign
    local dc = self.display:get()
    --error("Num Elements: " .. dc:GetNumOfElements())
end


---@param index number
function LargeTransportUI:setSelectedDestinationIndex(index)
    local destinationCount = #self.destinations
    if destinationCount > 0 then
        if index < 1 then
            index = 1
        elseif index >= destinationCount then
            index = #self.destinations
        end
        self.destinationIndex = index
        --self.display:setText(getNode(self.destinations[index]).caption)
        --self.display:setColor(0.6, 0.6, 0.6, 1)
        --self:setTravelEnabled(true)
    else
        --self.display:setText("No Destinations")
        --self.display:setColor(0.6, 0.6, 0.6, 1)
        --self:setTravelEnabled(false)
    end
    self:update()
end

function LargeTransportUI:refreshDestinations()
    --print("Updating destinations for node ", self.parent.name)
    local accessibleNodes = getAccessibleNodes(self.parent.name, 20)
    self.destinations = {}
    for _,v in pairs(accessibleNodes) do
        if v.accessible and v.nodeName ~= self.parent.name then
            ---@type DestinationItem
            table.insert(self.destinations, v)
        end
    end
    --if self.parent.name == "4" then
    --    printArrayToFile("Destinations.txt", self.destinations, 2)
    --    computer.stop()
    --end
    self:setSelectedDestinationIndex(self.destinationIndex)
end


--##########################################################################################
--################################                         #################################
--################################    Screen Driver  v2    #################################
--################################                         #################################
--##########################################################################################


---@class BigScreenV2
---@field screenRef ComponentReference<Screen>
---@field gpuRef FINComputerGPUT2
---@field screenSize Vector2D
---@field mapBounds table
---@field mapRange table
---@field mapScale table
---@field coordOffset Point
local BigScreenV2 = {}


---@param componentID string
---@return BigScreenV2
function BigScreenV2.new(componentID, gpuIndex)
    ---@type BigScreenV2
    local obj = {
        screenRef = ComponentReference.new(componentID),
        gpuRef =  computer.getPCIDevices(classes.GPU_T2_C)[gpuIndex + 1],
        mapBounds = 0,
        mapRange = 0,
        mapScale = 0,
        coordOffset = {x = -10, y = 50},
    }

    ---@type Screen
    local ref = obj.screenRef:get()

    print("GPU Ref: ", obj.gpuRef);
    obj.gpuRef:bindScreen(ref):await()

    print(obj.gpuRef);
    obj.gpuRef:drawLines({{0,0}, {100,100}}, 2, {1,1,1,1})
    obj.gpuRef:drawText({50,0}, "2D Drawing!", 10, {1,1,1,1}, false)
    obj.gpuRef:drawText({25,150}, "NIIICE!!!", 25, {1,0,0,1}, false)
    local screenSize = obj.gpuRef:getScreenSize()
    obj.screenSize = screenSize
    if obj.screenSize.x <= 0 then
        obj.screenSize.x = 1000
    end
    if obj.screenSize.y <= 0 then
        obj.screenSize.y = 1000
    end
    print("ScreenSize", obj.screenSize.x, obj.screenSize.y)


    obj.mapBounds = {left = -323929, top = -334717, right = 424166, bottom = 361634}
    obj.mapRange = {width = math.abs(obj.mapBounds.left) + math.abs(obj.mapBounds.right), height = math.abs(obj.mapBounds.top) + math.abs(obj.mapBounds.bottom)}
    obj.mapScale = {x = screenSize.x / obj.mapRange.width, y = obj.screenSize.y / obj.mapRange.height}
    --obj.gpuRef:drawBox({
    --    position = {0,0},
    --    size = {100, 100},
    --    rotation = 0,
    --    color = {1,1,1,1},
    --    image = "https://cdn.discordapp.com/attachments/378521107256573963/1185754812508282910/image.png?ex=6590c339&is=657e4e39&hm=576b9dad3b8878ab880e159575ec7f27f64939e5c763e3f85518613e7ab1577e&",
    --    imageSize = {100, 100},
    --    hasCenteredOrigin = true,
    --    horizontalTiling = false,
    --    verticalTiling = false,
    --    isBorder = false,
    --    margin = {0,0,0,0},
    --    isRounded = false,
    --    radii = 0,
    --    hasOutline = false,
    --    outlineColor = {0,0,0,0},
    --    outlineThickness = 0
    --})
    --obj.gpuRef:drawRect(
    --        {0,0},
    --        {screenSize.x, screenSize.y},
    --        {1,1,1,1},
    --        "https://cdn.discordapp.com/attachments/378521107256573963/1185754812508282910/image.png?ex=6590c339&is=657e4e39&hm=576b9dad3b8878ab880e159575ec7f27f64939e5c763e3f85518613e7ab1577e&",
    --        0
    --)

    --obj.gpuRef:drawLines({{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0}}, 5, {1,1,0,1})


    --registerEvent(obj.gpuRef, obj, nil, {
    --    ---@param self BigScreenV2
    --    ---@param position Vector2D
    --    ---@param wheelDelta number
    --    ---@param modifiers number
    --    OnMouseWheel = function(self, position, wheelDelta, modifiers)  end,
    --    ---@param self BigScreenV2
    --    ---@param position Vector2D
    --    ---@param modifiers number
    --    OnMouseUp = function(self, position, modifiers)  end,
    --    ---@param self BigScreenV2
    --    ---@param position Vector2D
    --    ---@param modifiers number
    --    OnMouseDown = function(self, position, modifiers)  end,
    --    ---@param self BigScreenV2
    --    ---@param position Vector2D
    --    ---@param modifiers number
    --    OnMouseMove = function(self, position, modifiers)
    --        print(position.x, position.y)
    --    end,
    --    ---@param self BigScreenV2
    --    ---@param position Vector2D
    --    ---@param modifiers number
    --    OnMouseLeage = function(self, position, modifiers)  end,
    --    ---@param self BigScreenV2
    --    ---@param position Vector2D
    --    ---@param modifiers number
    --    OnMouseEnter = function(self, position, modifiers)  end,
--
    --    ---@param self BigScreenV2
    --    ---@param c number
    --    ---@param code number
    --    ---@param modifiers number
    --    OnKeyUp = function(self, c, code, modifiers)  end,
    --    ---@param self BigScreenV2
    --    ---@param c number
    --    ---@param code number
    --    ---@param modifiers number
    --    OnKeyDown = function(self, c, code, modifiers)  end,
    --    ---@param self BigScreenV2
    --    ---@param character number
    --    ---@param modifiers number
    --    OnKeyCharacter = function(self, character, modifiers)  end,
--
    --    ScreenBound = function(self, oldScreen)  end,
    --    ProductionChanged = function(self, state)  end,
    --})

    setmetatable(obj, BigScreenV2)
    BigScreenV2.__index = BigScreenV2

    obj:paintMap()

    obj.gpuRef:flush()

    return obj
end

---@param x number
---@param y number
---@return Point|table
function BigScreenV2:GameCoordToScreenCoord(x, y)
    return {x = (x + math.abs(self.mapBounds.left)) * self.mapScale.x + self.coordOffset.x,
            y = (y + math.abs(self.mapBounds.top)) * self.mapScale.y + self.coordOffset.y}
end

function BigScreenV2:paintMap()
    local whalf = self.screenSize.x / 2;
    local hhalf = self.screenSize.y / 2;
    self.gpuRef:drawBox({
        position = {0,0},
        size = {whalf, hhalf},
        rotation = 0,
        color = {1,1,1,1},
        --image = "https://cdn.discordapp.com/attachments/378521107256573963/1185754812508282910/image.png?ex=6590c339&is=657e4e39&hm=576b9dad3b8878ab880e159575ec7f27f64939e5c763e3f85518613e7ab1577e&",
        image = "engine:/Game/FactoryGame/Interface/UI/Assets/MapTest/SlicedMap/Map_0-0.Map_0-0",
        imageSize = {100, 100},
        hasCenteredOrigin = false,
        verticalTiling = false,
        horizontalTiling = false,
        isBorder = false,
        margin = {0,0,0,0},
        isRounded = false,
        radii = {0,0,0,0},
        hasOutline = false,
        outlineThickness = false,
        outlineColor = {1,1,1,1}
    })
    self.gpuRef:drawBox({
        position = {whalf,0},
        size = {whalf, hhalf},
        rotation = 0,
        color = {1,1,1,1},
        --image = "https://cdn.discordapp.com/attachments/378521107256573963/1185754812508282910/image.png?ex=6590c339&is=657e4e39&hm=576b9dad3b8878ab880e159575ec7f27f64939e5c763e3f85518613e7ab1577e&",
        image = "engine:/Game/FactoryGame/Interface/UI/Assets/MapTest/SlicedMap/Map_1-0.Map_1-0",
        imageSize = {100, 100},
        hasCenteredOrigin = false,
        verticalTiling = false,
        horizontalTiling = false,
        isBorder = false,
        margin = {0,0,0,0},
        isRounded = false,
        radii = {0,0,0,0},
        hasOutline = false,
        outlineThickness = false,
        outlineColor = {1,1,1,1}
    })
    self.gpuRef:drawBox({
        position = {0,hhalf},
        size = {whalf, hhalf},
        rotation = 0,
        color = {1,1,1,1},
        --image = "https://cdn.discordapp.com/attachments/378521107256573963/1185754812508282910/image.png?ex=6590c339&is=657e4e39&hm=576b9dad3b8878ab880e159575ec7f27f64939e5c763e3f85518613e7ab1577e&",
        image = "engine:/Game/FactoryGame/Interface/UI/Assets/MapTest/SlicedMap/Map_0-1.Map_0-1",
        imageSize = {100, 100},
        hasCenteredOrigin = false,
        verticalTiling = false,
        horizontalTiling = false,
        isBorder = false,
        margin = {0,0,0,0},
        isRounded = false,
        radii = {0,0,0,0},
        hasOutline = false,
        outlineThickness = false,
        outlineColor = {1,1,1,1}
    })
    self.gpuRef:drawBox({
        position = {whalf, hhalf},
        size = {whalf, hhalf},
        rotation = 0,
        color = {1,1,1,1},
        --image = "https://cdn.discordapp.com/attachments/378521107256573963/1185754812508282910/image.png?ex=6590c339&is=657e4e39&hm=576b9dad3b8878ab880e159575ec7f27f64939e5c763e3f85518613e7ab1577e&",
        image = "engine:/Game/FactoryGame/Interface/UI/Assets/MapTest/SlicedMap/Map_1-1.Map_1-1",
        imageSize = {100, 100},
        hasCenteredOrigin = false,
        verticalTiling = false,
        horizontalTiling = false,
        isBorder = false,
        margin = {0,0,0,0},
        isRounded = false,
        radii = {0,0,0,0},
        hasOutline = false,
        outlineThickness = false,
        outlineColor = {1,1,1,1}
    })
end


---@class DrawContext
---@field stationListLocation Point
---@field stationListSize number
---@field selectedNode string
---@field hoveredNode string
---@field stationListIncludeJunction boolean

function BigScreenV2:repaint()
    --self.gpuRef:drawRect({0,0}, {self.screenSize.x, self.screenSize.y}, {1,1,1,1}, "https://cdn.discordapp.com/attachments/378521107256573963/1185754812508282910/image.png?ex=6590c339&is=657e4e39&hm=576b9dad3b8878ab880e159575ec7f27f64939e5c763e3f85518613e7ab1577e&", 0)
    self:paintMap()
    local drawnNodes = {}
    ---@type TransportNode[]
    local nodeList = {}

    for _, node in pairs(transportNodes) do
        self:drawNodeConnections(node, drawnNodes)
        nodeList[#nodeList + 1] = node
    end

    ---@type DrawContext
    local drawContext = {
        stationListLocation = {x = 0, y = 0},
        stationListSize = 0,
        hoveredNode = nil,
        selectedNode = nil,
        stationListIncludeJunction = true,
    }


    ---@param a TransportNode
    ---@param b TransportNode
    --usort(nodeList, function(a,b)
    --    if a == nil and b == nil then
    --        return 0
    --    elseif a == nil then
    --        return -1
    --    elseif b == nil then
    --        return 1
    --    end
    --    if a.location.x < b.location.x then
    --        return 1
    --    elseif a.location.x > b.location.x then
    --        return -1
    --    else
    --        if a.location.y < b.location.y then
    --            return 1
    --        elseif a.location.y > b.location.y then
    --            return -1
    --        else
    --            return 0
    --        end
    --    end
    --end)
    ---@param a TransportNode
    ---@param b TransportNode
    usort(nodeList, function(a, b)
        local aText = ""
        local bText = ""
        if a ~= nil then
            if a.caption ~= nil and string.len(a.caption) > 0 then
                aText = a.caption
            else
                aText = a.name
            end
        end
        if b ~= nil then
            if b.caption ~= nil and string.len(b.caption) > 0 then
                bText = b.caption
            else
                bText = b.name
            end
        end
        return CASE_INSENSITIVE_COMPARATOR(aText, bText)
    end)


    local t = ""
    for i, node in pairs(nodeList) do
        t = t .. tostring(i) .. " = " .. node.name .. "\n"
    end
    print(t)

    for _, node in pairs(nodeList) do
        self:drawNode(node, drawContext)
    end

    print("Drawing Finished")
    self.gpuRef:flush()
end


---@param node TransportNode
---@param drawnList table<string, any>
function BigScreenV2:drawNodeConnections(node, drawnNodes)
    if drawnNodes[node.name] ~= nil then
        return
    end
    drawnNodes[node.name] = true

    --error("Draw rect at " .. coords.x .. "x" .. coords.y)


    for _, gate in pairs(node.passthrough) do
        local e = self:drawTube(gate)
        if e ~= nil then
            self:drawNodeConnections(getNode(e), drawnNodes)
        end
    end

end

---@param node TransportNode
---@param drawContext DrawContext
function BigScreenV2:drawNode(node, drawContext)
    ---@type Point
    local coords -- = {x = 0, y = 0};

    coords = self:GameCoordToScreenCoord(node.location.x, node.location.y)

    local nodeText = node.name
    if node.caption ~= nil then
        nodeText = node.caption
    end
    local textSize = self.gpuRef:measureText(nodeText, 15, false):await()

    ---@type Color|table
    local nodeColor
    if node.junction then
        --nodeColor = structs.Color({0, 0.5, 0.5, 1})
        nodeColor = {0, 0.5, 0.5, 1}
    else
        --nodeColor = structs.Color({1, 0, 0, 1})
        nodeColor = {1, 0, 0, 1}
    end

    --self.gpuRef:drawRect({x = coords.x - 5, y = coords.y - 5}, {10, 10}, {1, 0, 0, 1}, nil, 0)
    self.gpuRef:drawBox({
        position = {x = coords.x - 8, y = coords.y - 8},
        size = {x = 16, y = 16},
        isRounded = true,
        radii = {8, 8, 8, 8},
        color = nodeColor,
    })
    if not node.junction then
        self.gpuRef:drawBox({
            position = {x = coords.x + 10, y = coords.y - 12},
            size = {x = textSize.x + 4, y = 24},
            isRounded = true,
            radii = {2,2,2,2},
            color = {0.7, 0.7, 0.7, 0.35}
        })
        self.gpuRef:drawText({x = coords.x + 12, y = coords.y - 15} , nodeText, 15, {0.4,0,0.4,1}, false)
    end


    if not node.junction or drawContext.stationListIncludeJunction then
        ---@type string
        local listText
        ---@type Color|table
        local listTextColor
        if node.junction then
            listText = "(" .. node.name .. ")"
            listTextColor = {0,0.3,0.3,1}
        else
            if node.caption ~= nil then
                listText = node.caption .. " (" .. node.name .. ")"
            else
                listText = node.name
            end
            listTextColor = {0.3,0,0.3,1}
        end
        textSize = self.gpuRef:measureText(listText, 15, false):await()
        local listCoords = drawContext.stationListLocation
        local y = listCoords.y + drawContext.stationListSize * 35
        local x = listCoords.x

        local boxWidth = math.max(200, 10 + textSize.x);

        self.gpuRef:pushClipRect({x, y}, {boxWidth, textSize.y + 6})
        self.gpuRef:drawBox({
            position = {x = x, y = y},
            outlineThickness = 3,
            outlineColor = {0.7,0.7,0.7,1},
            color = {0.7, 0.7, 0.7, 0.5},
            size = {x = boxWidth, y = textSize.y + 6}
        })

        --self.gpuRef:drawRect({x = x, y = y}, {x = 100, y = 18}, {1,0,0,1}, nil, 0)
        self.gpuRef:drawText({x + 5, y + 3} , listText, 15, listTextColor, false)

        self.gpuRef:popClip()

        if drawContext.hoveredNode == node.name or drawContext.selectedNode == node.name then
            self.gpuRef:drawLines({{x =  x + 100, y = y + 10}, {x = coords.x, y = coords.y}}, 2, {0,1,0,1})
        end

        drawContext.stationListSize = drawContext.stationListSize + 1
    end
end

---@param passthrough PassthroughGate
function BigScreenV2:drawTube(passthrough)
    local sourcePipeData = getHyperNetObject(passthrough.name, "pipe", tostring(passthrough.index))
    if sourcePipeData == nil then
        return
    end
    ---@type Build_PipeHyperStart_C
    local sourcePipe = component.proxy(sourcePipeData.id)
    --print(sourcePipe)
    local connectors = sourcePipe:getPipeConnectors()
    if connectors ~= nil then
        for __index, value in pairs(connectors) do
            --print(__index, value)
        end
    else
        print("Connector nil");
    end
    local result = enumeratePipe(connectors[1], 60, 0)
    --print("Result: " , result)
    local debugList = {}
    local coordList = {}
    ---@type Point|table
    local coords = nil
    if result ~= nil and #result > 0 then
        --printArrayToFile("result" .. name .. "x" .. index ..".txt", result, 5)
        --print(tostring(result:getType().name))
        for _, actor in pairs(result) do
            local q = self:GameCoordToScreenCoord(actor.location.x, actor.location.y)
            --print("Coord: " , q.x, q.y)
            debugList[#debugList + 1] = {q, false}
            if coords == nil then
                coordList[#coordList + 1] = structs.Vector2D({q.x, q.y})
                coords = {x = q.x, y = q.y}
            else
                local delta = {x = math.abs(q.x - coords.x), y = math.abs(q.y - coords.y)}
                if delta.x > 1 or delta.y > 1 then
                    coordList[#coordList + 1] = structs.Vector2D({q.x, q.y})
                    coords.x = q.x
                    coords.y = q.y
                end
            end
        end

        local comp = result[#result]
        if comp:getType().name == "Build_PipeHyperStart_C" then

            if comp.nick ~= nil then
                ---@type string
                local nick = comp.nick
                if string.sub( nick,0, 9) == "HyperNet " then
                    nick = string.sub(nick, 10)
                    local params = parseParams(nick)
                    self.gpuRef:drawLines(coordList, 5, {0,0.3,0.3,1})
                    printArrayToFile("temp/" .. passthrough.name .. "-" .. tostring(passthrough.index) .. ".txt" , debugList)
                    --error("")
                    return params.name
                end

            end
        end
    end
    return nil
end









--##########################################################################################
--################################                        ##################################
--################################ Hyper Net Signal Tower ##################################
--################################                        ##################################
--##########################################################################################


---@class HyperNetSignalTower
---@field parent TransportNode
---@field comp ComponentReference<Build_ModularIndicatorPole_C>
---@field busyLamp ModularIndicatorPole
---@field systemLamp ModularIndicatorPole
local HyperNetSignalTower = {}

---@param name string
---@return HyperNetSignalTower
function HyperNetSignalTower.new(name)
    local params = getHyperNetObject(name, "tower")
    if params == nil then
        return nil
    end
    local comp = ComponentReference.new(params.id)
    ---@type ModularIndicatorPole
    local ref = comp:get()
    ---@type HyperNetSignalTower
    local obj = {
        parent = getNode(name),
        comp = comp,
        busyLamp = ref:getModule(0),
        systemLamp = ref:getModule(1)
    }
    setmetatable(obj, HyperNetSignalTower)
    HyperNetSignalTower.__index = HyperNetSignalTower

    if obj.busyLamp~=nil then
        obj.busyLamp:setColor(1,1,1,0.5)
    end
    if obj.systemLamp ~= nil then
        obj.systemLamp:setColor(0,0,0,0)
    end
    return obj
end

---@param state boolean
function HyperNetSignalTower:setAlive(state)
    if self.systemLamp ~= nil then
        if state then
            self.systemLamp:setColor(1,0,1,1)
        else
            self.systemLamp:setColor(0,0,0,0)
        end
    end
end

function HyperNetSignalTower:update()
    --print("Tower for ", self.parent.name, " update")
    if scriptInfo.errorFlag then
        if self.systemLamp ~= nil then
            self.systemLamp:setColor(1, 0, 0, 4)
            self.busyLamp:setColor(0,0,0,0)
        elseif self.busyLamp ~= nil then
            self.busyLamp:setColor(1, 0, 0, 4)
        end
    else
        if self.parent.state == TransportState.Free then
            self.busyLamp:setColor(0,1,0,3)
        elseif self.parent.state == TransportState.Occupied then
            self.busyLamp:setColor(1,0,0,3)
        elseif self.parent.state == TransportState.WaitingTraveler then
            self.busyLamp:setColor(0,0,1,3)
        elseif self.parent.state == TransportState.WaitingExit then
            self.busyLamp:setColor(1,1,0,3)
        else
            self.busyLamp:setColor(1,0,1,5)
        end
    end
end









--##########################################################################################
--################################                         #################################
--################################         Helpers         #################################
--################################                         #################################
--##########################################################################################

function count(array)
    local count = 0
    if array ~= nil and type(array) == "table" then
        for _,_ in pairs(array) do
            count = count + 1
        end
    end
    return count
end

---@param nodeName string The source node
---@param nodes DestinationItem[] Visited nodes
---@param maxDepth number Max recursions
---@param level number Internally used to track depth
---@overload fun(nodeName:string):DestinationItem[]
---@overload fun(nodeName:string, maxDepth:number):DestinationItem[]
---@overload fun(nodeName:string, maxDepth:number, nodes:DestinationItem[]):DestinationItem[]
---@return DestinationItem[]
function getAccessibleNodes(nodeName, maxDepth, nodes, level)
    if level == nil then
        level = 1
    end
    if maxDepth > 0 and level > maxDepth then
        return nodes
    end
    if nodes == nil then
        nodes = {}
    end
    if nodes[nodeName] == nil then
        --print("getAccessibleNodes(nodeName=", nodeName, ",maxDepth=", maxDepth, ",nodes=", nodes, ",#nodes=", count(nodes), ",level=", level, ") -- Traversing")
        --print("nodes[", nodeName, "] is nil")
        local node = getNode(nodeName)
        ---@type DestinationItem
        local obj = {
            nodeName = nodeName,
            accessible = not node.junction,
            distance = 0,
        }
        nodes[nodeName] = obj
        --printArray(nodes)
        for k,v in pairs(node.passthrough) do
            --print("traversing gate " , v.gate.index)
            if v.next ~= nil then
                getAccessibleNodes(v.next.parent.name, maxDepth, nodes, level + 1)
            end
        end
        --printArray(nodes)
    else
        --print("getAccessibleNodes(nodeName=", nodeName, ") -- Skipping")
    end
    return nodes
end


---@param name string
---@param params table<string,string>
---@overload fun(name:string)
---@return TransportNode
function getNode(name, params)
    if name == nil then
        error("Node name can not be nil")
    end
    if transportNodes[name] ~= nil then
        return transportNodes[name];
    else
        if params == nil then
            params = getHyperNetObject(name, "entrance");
        end
        if params == nil then
            params = getHyperNetObject(name, "junction")
        end
        if params == nil then
            print("Node " , name, " not found")
            return nil;
            --error()
        end
        --print("Creating node " .. name)
        local node = TransportNode.new(name)
        --printArray(node)
        transportNodes[name] = node;
        if params.type == "entrance" then
            node.entranceComp = createReference(params.id)
            local exitParams = getHyperNetObject(name, "exit")
            node.exitComp = createReference(exitParams.id)
            local locComp = node.entranceComp:get()
            node.location = {x = locComp.location.x, y = locComp.location.y, z = locComp.location.z}
            node.junction = false
        else
            node.junction = true
            local locComp = createReference(params.id):get()
            node.location = {x = locComp.location.x, y = locComp.location.y, z = locComp.location.z}
        end

        if params.name ~= nil then
            node.caption = params.name
        end

        local gateCount = tonumber(params.gates)
        for i = 0,gateCount - 1,1 do
            local gate = PassthroughGate.new(params.node, tostring(i))
            node.passthrough[gate.index] = gate
        end
        if not node.junction then
            node:setEntryEnabled(false)
            node:setExitEnabled(false)
        end
        node.panel = SmallTransportPanel.new(name)
        node.ui = LargeTransportUI.new(node)
        node.tower = HyperNetSignalTower.new(name)
        node.sign = SignFormat.new(name)
        node.entranceTube = getHyperNetObject(name, "epipe")
        if node.entranceTube ~= nil then
            --print("Entrance tube found for " .. name)
            local tracerComp = component.proxy(node.entranceTube.id)
            registerEvent(tracerComp, node, TransportNode.transferFunction, nil, true, true)
        end
        if node.sign ~= nil then
            node.sign:setText(node.caption)
            node.sign:setIcon(SignIcons.Stop)
        end
        if node.ui ~= nil then
            node.ui:update()
        end

        return node
    end

end


function initNetwork()
    networkHandler(100, null, { -- table of message handlers
    })
end


function initComponentCache()
    components = component.findComponent("HyperNet");
    for _,v in pairs(components) do
        local comp = component.proxy(v)
        ---@type string
        local nick = comp.nick
        nick = string.sub(nick, 10)
        --print(nick);
        local params = parseParams(nick)
        params.nick = comp.nick
        params.id = comp.id
        params.proxy = comp
        componentNickData[comp.nick] = params
    end
    --printArray(componentNickData, 10)
end

---@param name string
---@param type string
---@param index number|string
---@overload fun(name:string, type:string):table<string,string>
---@return table<string,string>
function getHyperNetObject(name, type, index)
    --print("getHyperNetObject" , name, type, index)
    for _,v in pairs(componentNickData) do
        --print("--> test" , v.node, v.type, v.index)
        if (name == nil or v.node == name) and v.type == type and (index == nil or index == v.index) then
            --print("OK")
            return v
        end
    end
    return nil;
end

---@param type string
---@overload fun(name:string, type:string):table<string,string>
---@return table<string,string>[]
function getHyperNetObjectsOfType(type)
    ---@type table<string, string>[]
    local ret = {}
    for _,v in pairs(componentNickData) do
        --print("--> test" , v.node, v.type, v.index)
        if v.type == type then
            --print("OK")
            ret[#ret] = v
        end
    end
    return ret
end

function initTransportNetwork()
    computer.skip()
    for k,p in pairs(componentNickData) do
        computer.skip()
        --print("Type: " , p.type)
        if p.type == "entrance" then
            getNode(p.node, p)
        end
        if p.type == "junction" then
            getNode(p.node, p)
        end
    end
    rmessage("Initialized " .. tostring(componentNickData) .. " nodes")

    --local all = components;
    --for _,id in pairs(all) do
    --    if p[1] == "Bus" then
    --        getBus(p[2])
    --    end
    --end
end

--334 = arrow
--341 = stop
---@type BigScreenV2
local bigScreen = nil

function initScreen()
    if scriptInfo.gpu ~= nil and scriptInfo.screen ~= nil then
        local w = scriptInfo.screenWidth
        local h = scriptInfo.screenHeight
        --scriptInfo.gpu:bindScreen(scriptInfo.screen);
        scriptInfo.gpu:setSize(w, h);
        scriptInfo.gpu:fill(0,0,w,h, "O")

        scriptInfo.gpu:setForeground(1,1,1,0.5);

        scriptInfo.gpu:setText(0,0,"X")
        scriptInfo.gpu:setText(w - 1,0,"X")
        scriptInfo.gpu:setText(w - 1,h - 1,"X")
        scriptInfo.gpu:setText(0,h - 1,"X")

        scriptInfo.gpu:flush()
    end

    local t = getHyperNetObjectsOfType("HypertubeChart")
    if t ~= nil then
        for _, comp in pairs(t) do
            bigScreen = BigScreenV2.new(comp.id, 0);
            bigScreen:repaint()
            break
        end
    end
end


function drawNetwork()

end



function main()

    local t = {
        14, 22, 20, 17, 60, 34, 68, 50, 62, 65, 6, 57, 79, 22, 93, 78, 75, 39, 60, 81, 5, 25, 84, 3, 60, 79, 16, 61, 92, 72, 5, 0, 66, 46, 83, 44, 37, 82, 11, 94
    }


    --usort(t, CASE_INSENSITIVE_COMPARATOR)
    --printArray(t)

    initComponentCache()

    initTransportNetwork()

    initScreen()



    ---@type Build_PipeHyperStart_C
    --local temp = component.proxy("CE1E3D624BF81DC829B73EA1806444CF");

    --print(temp)
    --local route = enumeratePipe(temp:getPipeConnectors()[1])

    --printArrayToFile("route.txt", route)


    print( " -- - UPDATING NETWORK - - --  ")

    --printArrayToFile("transportNodes.txt", transportNodes, 2)
    --printArrayToFile("transportNodesRBEntJF.txt", transportNodes["RBEntJ"], 6)
    for k,v in pairs(transportNodes) do
        for k2,v2 in pairs(v.passthrough) do
            v2:updateDestination()
        end
    end
    --printArrayToFile("transportNodesD.txt", transportNodes, 2)
    for k,v in pairs(transportNodes) do
        if v.panel ~= nil then
            v.panel:refreshDestinations()
        end
        if v.tower ~= nil then
            v.tower:update()
        end
        if v.ui ~= nil then
            v.ui:refreshDestinations()
        end
    end

    local alive = {
        counter = 0,
        state = false
    }
    scriptInfo.error_handler = function()
        --unregisterAll();
        event.ignoreAll()

        for k,v in pairs(transportNodes) do
            scriptInfo.errorFlag = true
            if v.panel ~= nil and v.panel.btnTravel ~= nil then
                --registerEvent(v.panel.btnTravel, nil, function(self, event, parameters, parameterOffset)  end)
                initModularButton(v.panel.btnTravel, function(self)
                    computer.reset()
                end, rgba(1, 0, 0, 2))

            end
            if v.ui ~= nil then
                v.ui:refreshDestinations()
            end
            if v.tower ~= nil then
                v.tower:update()
            end
        end

        while true do
            local result = {event.pull(1) }
            --print(result[1])
            processEvent(result)
        end

    end

    scriptInfo.reset_handler = function()
        for k,v in pairs(transportNodes) do
            if v.tower ~= nil then
                if v.tower.systemLamp ~= nil then
                    v.tower.systemLamp:setColor(1,1,0,4)
                    if v.tower.busyLamp ~= nil then
                        v.tower.busyLamp:setColor(0,0,0,0)
                    end
                end
            end
        end
    end


    schedulePeriodicTask(PeriodicTask.new(function(self)
        if self.counter == 0 then
            self.state = not self.state
            if self.state then
                self.counter = 0
            else
                self.counter = 5
            end
            ---@param v TransportNode
            for _, v in pairs(transportNodes) do
                v:setAliveFlash(self.state)
            end
        else
            self.counter = self.counter - 1
        end

    end, alive, 1000, "Alive Update"))

    --printArrayToFile("transportNodes.txt", transportNodes, 2)
    --printArrayToFile("transportNodesRBEntJ.txt", transportNodes["RBEntJ"], 6)
    --printArrayToFile("transportNodes2.txt", transportNodes["RozeBase"], 6)
    --printArrayToFile("transportNodes3.txt", transportNodes["5"], 6)

    for __index, v in pairs(transportNodes) do
        printArrayToFile("nodes/transport_".. v.name ..".txt", v, 6)
    end


            --print(computer.millis());
    ---@type SizeableModulePanel
    local comp = component.findComponent("HyperNetDebugPanel")[1];
    if comp ~= nil then
        ---@type SizeableModulePanel
        local testPanel = component.proxy( comp );
        local btn = testPanel:getModule(1,9);
        initModularButton(btn, function(self)
            --print(computer.millis());
            error()
        end);
        btn.enabled = true
    end
    --test:getPrefabSignData()

    --local v = getNode("1")
    --v:setEntryExitEnabled(true)
    --v.passthrough[1]:setEnabled(true)
    --v = getNode("2")
    --v:setEntryExitEnabled(true)
    --v.passthrough[0]:setEnabled(true)

    --initNetwork()

    --printArray(stock.Coal, 2)

    --rmessage("Startup delay")

    --wait(4000)

    rmessage("System Operational")

    --schedulePeriodicTask(PeriodicTask.new(scheduler, nil, nil, "Fluid Scheduler"))

    print( " -- - INIT DONE - - --  ")


    print( " -- - STARTUP DONE - - --  ")

    commonMain(1, 0.1)

end
