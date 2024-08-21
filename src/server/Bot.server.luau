--!optimize 2
--!native

print("Running Bot Roblox")

local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")

local MemoryStore = MemoryStoreService:GetHashMap("Servers")
local exists = MemoryStore:GetAsync("Server") 

local Reserve,Ids = exists and exists[1], exists and exists[2]
local CONFIG = require(script.Parent.CONFIG)

local ADMINS = CONFIG.ADMINS
local BLACKLIST = CONFIG.BLACKLIST
local DEFAULT_TIMEOUT = CONFIG.DEFAULT_TIMEOUT

game:GetService("MessagingService"):SubscribeAsync("UpdateURL",function(msg)
    local data = HttpService:JSONDecode(msg.Data)
    CONFIG.URL.value = data.url
end)

local AUTOREJOIN = CONFIG.SERVER_RESTART
local restartTime = DateTime.now().UnixTimestamp+AUTOREJOIN or 9999999
task.wait(2)
local closed = false

local env = require(game.ServerScriptService.Env)
local Runner = require(game.ServerScriptService.Runner)
local WebSocket = require(game.ServerScriptService.WebSocket)

local DISCORD_TOKEN = CONFIG.DISCORD_TOKEN
local GATEWAY_URL = "wss://gateway.discord.gg"
local URL = CONFIG.URL
local UPDATE_INTERVAL = 1/20
local MAX_STRING_HEIGHT = CONFIG.MAX_STR_HEIGHT


if not RunService:IsStudio() then
    --// Restarts the server memory store | ensures only one server is running
    if game.PrivateServerId =="" or game.PrivateServerId ~= Ids or not exists then
        local reserver,id 
        if not exists then
            reserver,id = TeleportService:ReserveServer(game.PlaceId)
        else
            reserver,id = unpack(exists)
        end
        MemoryStore:SetAsync("Server",{reserver,id},20)    
        local function handlePlayer(v)
            TeleportService:TeleportToPrivateServer(game.PlaceId,reserver,{v})
            task.wait(7)
            if v:IsDescendantOf(game) then
                v:Kick("Server is closing")
            end
        end
        game.Players.PlayerAdded:Connect(handlePlayer)
        for i,v in game.Players:GetPlayers()do
            handlePlayer(v)
        end
        return
    end

    MemoryStore:SetAsync("Server",{Reserve,Ids},20)    


    local RejoinFunc = function()
        closed = true
        local reserver,id = TeleportService:ReserveServer(game.PlaceId)
        MemoryStore:SetAsync("Server",{reserver,id},20)    
        task.wait(1)
        print("Teleporting")
        local function handlePlayer(v)
            TeleportService:TeleportToPrivateServer(game.PlaceId,reserver,{v})
            task.wait(7)
            if v:IsDescendantOf(game) then
                v:Kick("Server is closing")
            end    
        end
        for i,v in game.Players:GetPlayers()do
            handlePlayer(v)
        end

    end
    if AUTOREJOIN then
        task.spawn(function()
            while DateTime.now().UnixTimestamp < restartTime do
                task.wait(1)
            end
            RejoinFunc()
        end)
    end
end

task.spawn(function()
    while task.wait(15) and not closed do
        MemoryStore:SetAsync("Server",{Reserve,Ids},20)    
    end
end)

local Processes = {

}

local colors = {
    Black = "[0;30m", 
    Red = "[0;31m",
    Green = "[0;32m",
    Yellow = "[0;33m",
    Blue = "[0;34m",
    Purple = "[0;35m",
    Cyan = "[0;36m",
    White = "[0;37m"
}


local function createText(text,color)
    if color == 3 then
        return `[0;31m{text}[0m`
    elseif color == 2 then
        return `[0;33m{text}[0m`
    end
    return `[0;37m{text}[0m`
end

local function getLen(t)
    local amt = 0
    for i,v in t do amt +=1 end 
    return amt
end

local function truncateString(inputString)
    local lines = {}
    for line in inputString:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    if #lines > MAX_STRING_HEIGHT then
        local startLine = #lines - MAX_STRING_HEIGHT + 1
        local truncatedLines = {}
        for i = startLine, #lines do
            table.insert(truncatedLines, lines[i])
        end

        return table.concat(truncatedLines, "\n")
    else
        return inputString
    end
end

local function sendMessageALL(err)
    for i,v in Processes do
        v.output ..= createText(string.format(`[%.3f] %s\n`,os.clock()-v.start,err),3)
    end
end

local function tableToString(t, indent,lookup,bypass)
    
    if type(t) == "table" and not bypass then
        local str = tostring(t)
        if not string.find(str,"table:") then
            return tostring(t)
        end
    end
    
    lookup = lookup or {}
    indent = indent or 0 
    local indentString = string.rep("  ", indent) 
    local result = "{\n"
    lookup[t] = true
    for key, value in pairs(t) do
        local key_ = typeof(key) == "string" and  `"{key}"` or  tostring(key)
        result = result .. indentString .. "  [" .. tostring(key_) .. "] = " 

        if type(value) == "table" then
            if lookup[value] then continue end 
            result = result .. tableToString(value, indent + 1,lookup,bypass)  
        else
            result = result .. '' .. tostring(value) .. ',\n' 
        end
    end

    result = result .. indentString .. "}\n"  
    return result
end




local function getLinkFromData(data)
    local channel_id,msgID = data.d.channel_id,data.d.data.target_id
    return msgID and `https://discord.com/channels/@me/{channel_id}/{msgID}` or ""
end

local function createEmbed(data, logs,image)
    local link = getLinkFromData(data)
    local msg = {
        content = `Running {link or ""}\n`,
        tts = false,
        embeds = {
            {
                id = 391161511,
                title = "Output",
                description = ("```ansi\n%s```"):format(logs),
                fields = {},
                image =   image and {
                    url = image
                } 
            }
        },
        components = {},
        actions = {}
    }

    return msg
end


local function receiveInteraction(interactionId, interactionToken,pass,data,other)
    local url = URL.value.."/callback"
    local headers = {
        ["Content-Type"] = "application/json"
    }

    local toSend = nil

    if pass then
        toSend = {
            type = 4,
            data = createEmbed(data,"")
        }
    elseif  other then
        toSend = {
            type = 4,
            data = {
                content = other
            }
        }
    else
        toSend = {
            type = 4,
            data = {
                content = "Failed to parse message "..getLinkFromData(data)
            }
        }
    end

    local requestData = {
        Url = url,
        Method = "POST",
        Headers = headers,
        Body = HttpService:JSONEncode({
            interactionId = interactionId,
            interactionToken = interactionToken,
            data = toSend
        })
    }


  local sus,msg = pcall(function()
        HttpService:RequestAsync(requestData)
  end)
  if not sus then
    warn(msg)
  end
end


local function respondToInteraction(interactionToken, responseContent)
    local url = URL.value.."/respond"
    local headers = {
        ["Content-Type"] = "application/json"
    }

    local requestData = {
        Url = url,
        Method = "PATCH",
        Headers = headers,
        Body = HttpService:JSONEncode({token = interactionToken,data = responseContent}),
    }

    local sus,msg = pcall(function()
         HttpService:RequestAsync(requestData)
    end)
    if not sus then
        warn(msg)
    end
end

local function getDataInLink(link)
    local url = URL.value.."/readfile"
    local headers = { 
        ["Content-Type"] = "application/json"
    }

    local requestData = {
        Url = url,
        Method = "PATCH",
        Headers = headers,
        Body = HttpService:JSONEncode({url = link}),
    }

    local sus,msg = pcall(function()
         return HttpService:RequestAsync(requestData)
    end)
    if not sus then
        warn(msg)
        return false
    end
    return msg.Body
end

local function runCode(code,data)
    local env = table.clone(env)
    local lastOutput = ""
    local start = os.clock()+2

    local thread = {}
    thread.output = ""
    thread.start = start

    env.log = function(text,color,newLine)
        local time = os.clock()-start
        thread.output ..= (string.format(`[%.3f] %s\n`,time,(colors[color] or "")..text..(newLine and '\n' or "")))
    end

    env.print = function(...)
        local text = ""
        local array = {...}
        local length = select("#",...)
        local time = os.clock()-start
        for i = 1,length do
            local value = type(array[i]) == "table" and tableToString(array[i]) or tostring(array[i])
            text ..= value .. " "
        end
        thread.output ..= createText(string.format(`[%.3f] %s\n`,time,text))
    end
    
    env.debugprint = function(...)
        local text = ""
        local array = {...}
        local length = select("#",...)
        local time = os.clock()-start
        for i = 1,length do
            local value = type(array[i]) == "table" and tableToString(array[i],nil,nil,true) or tostring(array[i])
            text ..= value .. " "
        end
        thread.output ..= createText(string.format(`[%.3f] %s\n`,time,text),2)
    end

    env.warn = function(...)
        local text = ""
        local array = {...}
        local length = select("#",...)
        local time = os.clock()-start
        for i = 1,length do
            text ..= tostring(array[i]) .. " "
        end
        thread.output ..= createText(string.format(`[%.3f] %s\n`,time,text),2)
    end

    env.error = function(msg,context)
        local time = os.clock()-start
        thread.output ..= createText(string.format(`[%.3f] %s\n`,time,msg),3)
        local running = coroutine.running()
        task.defer(coroutine.close,running)
        coroutine.yield()
    end


    local fx,script = Runner.load(code,env)
    if not fx then
        return false
    end

    thread.script = script
    Processes[data] = thread

    thread.timeOutThread = task.spawn(function()
        local waitTime = 0
        local TIMEOUT = script:GetAttribute("TimeOut") or DEFAULT_TIMEOUT
        while os.clock()-thread.start < TIMEOUT do
            TIMEOUT = script:GetAttribute("TimeOut") or DEFAULT_TIMEOUT
            waitTime += task.wait(UPDATE_INTERVAL)
            if lastOutput ~= thread.output then
                thread.output = truncateString(thread.output)
                lastOutput = thread.output
                respondToInteraction(data.d.token,createEmbed(data,thread.output))
            end
        end
        thread.output ..= string.format(`[2;36m[%.3f] %s[0m`,os.clock()-start,`Script Reached its lifespan ({TIMEOUT}s)`)
        respondToInteraction(data.d.token,createEmbed(data,thread.output))

        Processes[data]  = nil
        script:Destroy()
    end)

    return true
end

local function isGuild(data)
    return not not data.d.guild
end

local function getCode(content)
    local v1 = string.find(content,"```lua")
    local v2 = string.find(content,"```")
    local start = v1 and v1 + 6 or (v2 or 0) + 3

    local endA = string.find(content,"```",start)
    if endA then
        endA -= 1
    end
    
    if not v1 and not v2 then
        return content
    end

    return content:sub(start,endA)
end

local function handleCommand(commandName, options,data,user)
    
    if table.find(BLACKLIST,tostring(user.id)) then
        return false, `You are blacklisted`
    end
    
    if commandName == 'rcompile' then
        local command = options.options[1].value

        return runCode(command,data)
    elseif commandName == 'rCompile' then 
        local _,value = next(options.resolved.messages)
        local content = value.content
         
        local attachment = value.attachments[1]
        if attachment and attachment.url then
            local url = attachment.url
            task.spawn(function()
                local response = getDataInLink(url)
                content = type(response) == "string" and response or "a"
                runCode(content,data)
            end)
            return true
        end
        local code = getCode(content)

        return runCode(code,data)
    elseif commandName == "reset" then
        if table.find(ADMINS,tostring(user.id)) then
            task.delay(3,function()
                restartTime = 0
            end)
            return false, `Server Restarting`
        end
        return false, `User does not have permission to use this command`
    elseif commandName == "setalive" then
        if table.find(ADMINS,tostring(user.id)) then
            local op = options.options[1].value
            local amt = loadstring(`return {op}`)
            if not amt then
                return false, `Invalid time`
            end
            amt = amt()
            if tonumber(amt) == nil then
                return false, `Invalid time`
            end
            restartTime = DateTime.now().UnixTimestamp + amt 
            return false, `Server Updated | Server will restart <t:{restartTime}:R>`
        end
        return false, `User does not have permission to use this command`
    elseif commandName == "clear" then
        local i = 0
        for k,v in Processes do
            i+=1
            pcall(function()
                v.script:Destroy()
                task.cancel(v.timeOutThread)
                Processes[k] = nil
            end)
        end
        return false, `Stopped {i} task(s)`
    elseif commandName == "alive" then
        return false, `Server will restart <t:{restartTime}:R>`
    elseif commandName == "rtasks" then
        return false,`there is {getLen(Processes)} task(s) running`
    end
    return "NONE"
end

local remote = game.ReplicatedStorage.RemoteEvent
LogService.MessageOut:Connect(function(errmsg,type)
    remote:FireAllClients(errmsg,type)
    if type == Enum.MessageType.MessageError then
        local msg = errmsg
        if errmsg:find("Script timeout:") then
            msg = "Script timeout: exhausted allowed execution time from one of the script"
            sendMessageALL(msg)
        end
    end
end)

local function sendIdentifyPayload(websocket)
    local identifyPayload = {
        op = 2,
        d = {
            token = DISCORD_TOKEN,
            intents = 513,
            properties = {
                ["$os"] = "linux",
                ["$browser"] = "my_library",
                ["$device"] = "my_library"
            }
        }
    }
    websocket.Send(HttpService:JSONEncode(identifyPayload))
end

local function sendResumePayload(websocket, sessionId, lastS)
    local resumePayload = {
        op = 6,
        d = {
            token = DISCORD_TOKEN,
            session_id = sessionId,
            seq = lastS
        }
    }
    websocket.Send(HttpService:JSONEncode(resumePayload))
end


local function SendHeartbeat(websocket,s)
    local heartbeatPayload = {
        op = 1,
        d = s
    }
    websocket.Send(HttpService:JSONEncode(heartbeatPayload))
end

local socket 
local function connect(resume, sessionId, lastS)
    local pass,websocket = pcall(WebSocket.Connect,GATEWAY_URL,2)
    socket = websocket
    if not pass then
        warn("failed to connect, reconnecting",websocket)
        task.wait(5)
        connect()
        return
    end
    print("Reconnected")
    local disconnected = false

    websocket.OnMessageReceived:Connect(function(response: string?)
        local data = HttpService:JSONDecode(response) 
        if data.s then
            lastS = data.s
        end
        if data.t == 'INTERACTION_CREATE' then
            local is_guild = isGuild(data)

            local user = is_guild and data.d.member.user or data.d.user

            local interactionId = data.d.id
            local interactionToken = data.d.token
            local interactionData = data.d.data

            print("Received Request From User:",user.username,interactionData.name,data)

            local pass,other = handleCommand(interactionData.name, interactionData,data,user)
            if pass == "NONE" then
                 return
            end

            receiveInteraction(interactionId,interactionToken,pass,data,other)
        elseif data.op == 10 then
            local interval = data.d.heartbeat_interval
            task.spawn(function()
                task.wait(math.random())
                while not disconnected do
                    task.wait(interval/1000)
                        local pass = pcall(function()
                            SendHeartbeat(websocket,lastS)
                    end)
                    if not pass then
                            print("Failed To send HeartBeat")
                            disconnected = true
                            pcall(websocket.Disconnect)  
                            connect(false)
                    end
                end
            end)
            if resume and sessionId then
                sendResumePayload(websocket, sessionId, lastS)
            else
                sendIdentifyPayload(websocket)
            end


        elseif data.op == 7 then
            print("Received Reconnect opcode, reconnecting...")
            disconnected = true
            pcall(websocket.Disconnect)
            connect(true, sessionId, lastS) 
        elseif data.op == 9 then
            print("Received Invalid Session opcode, reconnecting...")
            disconnected = true
            pcall(websocket.Disconnect)
            connect(false)
        elseif data.t == "READY" then
            sessionId = data.d.session_id
            print("Session started with ID:", sessionId)
        end
    end)
    
    websocket.OnDisconnect:Connect(function(a)
        if disconnected or closed then return end 
        disconnected = true
        task.wait()
        connect(true, sessionId, lastS) 
    end)
end

game:BindToClose(function()
    if not closed then 
        MemoryStore:RemoveAsync("Server")   
    end
    closed = true 
    pcall(socket.Disconnect)
end)

--// destroy env so people can't access it
script.Parent.CONFIG:Destroy()
connect(false)
