AddHook("OnVarlist", "ChatLogger", function(var, netid)
    if var and var[0] == "OnTalkBubble" then
        logToConsole("`9[CHAT EVENT] `wNetID: " .. tostring(netid))
    end
end)

AddHook("OnTextPacket", "ChatTextLogger", function(flag, packet)
    if packet and packet:find("action|input", 1, true) then
        local teks = packet:match("|text|([^\n]*)")

        if teks then
            logToConsole("`9[CHAT] `w" .. teks)
        end
    end
end)