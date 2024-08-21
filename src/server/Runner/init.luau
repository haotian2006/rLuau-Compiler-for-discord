local module = {}

local runnerScript = script.Script
local Https = game:GetService("HttpService")

local info = {}

function module.load(str,env)
    local clone = runnerScript:Clone()
    clone.Name = Https:GenerateGUID()
    info[clone] = {str,env}
    clone.Parent = game.ServerScriptService
    clone.Enabled = true
    clone.AttributeChanged:Wait()
   
   local pass = clone:GetAttribute("pass")
   if not pass then
        clone:Destroy()
   end
   return pass,clone
end
function module.getData(script)
    local data = info[script]
    info[script] = nil
    return data
end

return module
