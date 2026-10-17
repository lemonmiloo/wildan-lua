AddHook("OnTextPacket", "ChatLogger", function(flag, packet)
    if packet:find("action|input") then
        local teks = packet:match("|text|(.*)")

        if teks and teks ~= "" then
            logToConsole("`9[CHAT] `w" .. teks)
        end
    end

    return false
end)