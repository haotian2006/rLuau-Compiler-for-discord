local mod = loadstring(script:GetAttribute("Source"))
local env = require(game.ServerScriptService.Env)
setfenv(mod,env::any)
return mod()