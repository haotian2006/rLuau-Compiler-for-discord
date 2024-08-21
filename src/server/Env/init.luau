

local hooker = require(game.ServerScriptService.HookedInstance)
local hookvalue,getvalue = hooker.getdata()

hooker.getdata = nil

table.freeze(hooker)
local custom = {
    Instance = table.freeze({
        new = function(type,parent)
            local inst
            parent = getvalue(parent)
            if type == "ModuleScript" then
                inst = script.ModuleScript:Clone()
            else
                inst = Instance.new(type)
            end
            inst.Parent = parent
            return hooker.new(inst)
        end,
        fromExisting  = function(inst) 
            return hooker.new(Instance.fromExisting(getvalue(inst))) 
        end,
    })
}

local env = getfenv(0)

--[[
return table.freeze(setmetatable({},{__index = function(_,k)
    return env[k]
end,}))
]]


return table.freeze(setmetatable(custom,{__index = function(_,k)
    local value = env[k]
    return hookvalue(value)
end,}))