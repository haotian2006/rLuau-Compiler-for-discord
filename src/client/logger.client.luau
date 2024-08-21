game.ReplicatedStorage.RemoteEvent.OnClientEvent:Connect(function(msg,err:Enum.MessageType)
    if err == Enum.MessageType.MessageError then
        error(msg)
    elseif err == Enum.MessageType.MessageWarning then
        warn(msg)
        return
    end
    print(msg)
end)