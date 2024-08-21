local module = {}

local TextService = game:GetService("TextService")

local cache = {}
local lookup = {}

local _ENV = require(game.ServerScriptService.CONFIG)
local HOSTID = _ENV.HOST_BOT_USERID

function module.new(instance:Instance)
    if typeof(instance) ~= "Instance" then
        return instance
    end
    if cache[instance] then return cache[instance] end 
    local value = table.freeze(setmetatable({_instance = instance.Name,__type = "HookedInstance"},module))

    cache[instance] = value
    lookup[value] = instance
    instance.Destroying:Connect(function()
        cache[instance] = nil
        lookup[value] = nil
    end)
    return  value
end

local function getvalue(x)
    return lookup[x] or x
end

local cachedFunctions = {}

local BannedMethods = {
    [game.Players.BanAsync] = true,
}

game.Players.PlayerAdded:Connect(function(plr)
    BannedMethods[plr.Kick] = true
end)


local banned = function()
    return "This function is banned"
end


local function tableToString(t, indent,lookup)

    lookup = lookup or {}
    indent = indent or 0 
    local indentString = string.rep("  ", indent) 
    local result = "{\n"
    lookup[t] = true
    for key, value in pairs(t) do
        local key = typeof(key) == "string" and  `"{key}"` or  tostring(key)
        result = result .. indentString .. "  [" .. tostring(key) .. "] = " 

        if type(value) == "table" then
            if lookup[value] then continue end 
            result = result .. tableToString(value, indent + 1,lookup)  
        else
            result = result .. '' .. tostring(value) .. ',\n' 
        end
    end

    result = result .. indentString .. "}\n"  
    return result
end

local function filterString(str)
    return TextService:FilterStringAsync(str,7212185804, Enum.TextFilterContext.PublicChat)
end

local function hookValue(value,isTuple)
    if isTuple then
        for i,v in value do
            value[i] = hookValue(v)
        end
        return table.unpack(value)
    end
    if typeof(value) == "Instance" then
        return module.new(value)
    elseif type(value) == "function" then
        if BannedMethods[value] then
            return banned
        end
        
        if cachedFunctions[value] then
            return cachedFunctions[value]
        end
        
        if value == require then
            cachedFunctions[value] = function(path)
                assert(type(tonumber(path)) ~= "number" ,"Cannot Require an asset")
                return require(getvalue(path))
            end
            return cachedFunctions[value]
        end
        
        cachedFunctions[value] = function(...)
            local data = {...}
            for i,v in data do
                data[i] = getvalue(v)
            end
            local returnvalue = {value(table.unpack(data))}
            return hookValue(returnvalue,true)
        end
        return  cachedFunctions[value]
    elseif type(value) == "table" then
        if value.__type == "HookedInstance" then
            return value
        end
        local wasFrozen = table.isfrozen(value)
        if wasFrozen then
            value = table.clone(value)
        end
        for i,v in value do
            value[i] = hookValue(v)
        end
        if wasFrozen then
            value = table.freeze(value)
        end
    end
    return value
end

module.getdata = function()
    return hookValue,getvalue
end


local BannedClassNamed = {
    "TeleportService"

}

module.__index = function(self,i)
    local instance:Instance = lookup[self]
    if not instance then
        return error(`Instance does not exists in registry \n {tableToString(self)} `)
    end
    if i == "ClassName" then
        error("class name?")
    end
    if table.find(BannedClassNamed,instance.ClassName) then
        error(`{instance.ClassName} is blacklisted`)
    end
    if instance:IsA("Players") and i == "ClearAllChildren" then
        error("Using ClearAllChildren on Players is blacklisted")
    end

    return hookValue(instance[i])
end

module.__newindex = function(self,i,v)
    local instance:Instance = lookup[self]
    if not instance then
        return error(`Instance does not exists in registry \n {tableToString(self)} `)
    end
    if instance:IsA("Player") and instance.UserId == tonumber(HOSTID) then
        error("modifying the host is blacklisted")
    end

    if instance:IsA("ModuleScript") and i == "Source" then
        assert(typeof(v) == "string","Source must be a string")
        instance:SetAttribute("Source",v)
        return
    end
    
    if instance:IsA("TextLabel") or instance:IsA("TextBox") and i == "Text" or i == "PlaceholderText" then
        v = filterString(tostring(v))
    end

    instance[i] = getvalue(v)
end

module.__tostring = function(self,i,v)
    return tostring(self._instance)
end

return module
