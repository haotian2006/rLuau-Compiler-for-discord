local runner = require(game.ServerScriptService.Runner)

local data =runner.getData(script)
local str,env = table.unpack(data)
local loaded = loadstring(str,"Script")

local hooker = require(game.ServerScriptService.HookedInstance)

script:SetAttribute("pass",not not loaded)
if loaded then
    if env then
        env.script = hooker.new(script)
        setfenv(loaded,env)
    end
    task.delay(2,function()
        local pass,err = pcall(loaded)
        if not pass then
            env.error(err)
        else
            script:SetAttribute("TimeOut",tonumber(err) or 15)
        end
    end)
end