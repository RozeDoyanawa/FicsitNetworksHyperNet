event.ignoreAll()
event.clear()

filesystem.initFileSystem("/dev")

scriptInfo = {
    ---@type NetworkCard
    --network = component.proxy("0FB7C81A4D8ACBDB97B3D3BAE8F8A507"),
    name = "HyperNetManager",
    fileSystemMonitor = true,
    port = 100,
    preventResetAll = true,
    errorFlag = false,
    mainProgram = "HyperNet.lua",
    ---@type GPU_T1_C
    gpu = nil,
}

drive = ""
for _,f in pairs(filesystem.childs("/dev")) do
    if not (f == "serial") then
        drive = f
        print(drive)
        break
    end
end
filesystem.mount("/dev/" .. drive, "/")

--main = function () end

json = filesystem.doFile("/json.lua")
---@type fun(arr:table,comp:fun(a,b))
usort = filesystem.doFile("/sort.lua")
filesystem.doFile("/Common.lua")

commonInit()
