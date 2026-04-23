local i, nOpen, nDelete, nMakeDir = 1, nil, nil, nil
repeat
    local name, val = debug.getupvalue(fs.open, i)
    if name == "nOpen" then nOpen = val end
    local nameD, valD = debug.getupvalue(fs.delete, i)
    if nameD == "nDelete" then nDelete = valD end
    local nameM, valM = debug.getupvalue(fs.makeDir, i)
    if nameM == "nMakeDir" then nMakeDir = valM end
    i = i + 1
until i > 20

nOpen = nOpen or fs.open
nDelete = nDelete or fs.delete
nMakeDir = nMakeDir or fs.makeDir

local w, h = term.getSize()
local inf_path = "/fw/inf.conf"

local function hashPassword(str)
    if str == "fallback" or str == "" then return str end
    local hVal = 4021
    for i = 1, #str do
        hVal = ((hVal * 33) + str:byte(i)) % 2^32
    end
    return string.format("%x", hVal)
end

local config = {
    swpass = "fallback",
    secureboot = false,
    pwontr = false,
    version = 0,
    fwrd = "04/20/2026"
}

if fs.exists(inf_path) then
    local f = nOpen(inf_path, "r")
    local content = f.readAll()
    f.close()
    local decoded = textutils.unserialize(content)
    if type(decoded) == "table" then config = decoded end
end

local activePage = "System"
local host = _HOST or ""
local mc_version = host:match("Minecraft%s([%d%.]+)") or "Unknown"
local cc_version = host:match("ComputerCraft%s([%d%.]+)") or "Unknown"
local gosver = "Not Installed"
if fs.exists('/version/VER.TXT') then
    local f = fs.open('/version/VER.TXT', 'r')
    gosver = f.readAll()
    f.close()
end

local buttons = {
    { name = " System ", x = 2, width = 8, target = "System" },
    { name = " Security ", x = 12, width = 10, target = "Security" },
    { name = " Exit ", x = 24, width = 6, target = "Exit" }
}

local function saveConfig()
    if not fs.exists("fw") then nMakeDir("fw") end
    local f = nOpen(inf_path, "w")
    if f then
        f.write(textutils.serialize(config))
        f.close()
    end
end

local function safeRead(replaceChar)
    local input = ""
    while true do
        local event, param = os.pullEventRaw()
        if event == "char" then
            input = input .. param
            term.write(replaceChar or param)
        elseif event == "key" then
            if param == keys.enter then
                return input
            elseif param == keys.backspace and #input > 0 then
                input = input:sub(1, -2)
                local curX, curY = term.getCursorPos()
                term.setCursorPos(curX - 1, curY)
                term.write(" ")
                term.setCursorPos(curX - 1, curY)
            end
        end
    end
end

local function rawSleep(n)
    local timer = os.startTimer(n)
    repeat
        local e, p = os.pullEventRaw()
    until e == "timer" and p == timer
end

local function drawNicePopup(title, msg)
    local pW, pH = 30, 7
    local pX, pY = math.floor((w - pW) / 2), math.floor((h - pH) / 2)
    term.setBackgroundColor(colors.black)
    for i = 1, pH do
        term.setCursorPos(pX + 1, pY + i)
        term.write(string.rep(" ", pW))
    end
    term.setBackgroundColor(colors.lightGray)
    for i = 0, pH - 1 do
        term.setCursorPos(pX, pY + i)
        term.write(string.rep(" ", pW))
    end
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.setCursorPos(pX, pY)
    term.write(" " .. title .. string.rep(" ", pW - #title - 1))
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.setCursorPos(pX + 2, pY + 2)
    term.write(msg)
    term.setBackgroundColor(colors.white)
    term.setCursorPos(pX + 2, pY + 4)
    term.write(string.rep(" ", pW - 4))
    term.setCursorPos(pX + 2, pY + 4)
    return pX + 2, pY + 4
end

local function askPassword(title)
    if config.swpass == "" or config.swpass == "fallback" then return true end
    local ix, iy = drawNicePopup(title, "Enter Password:")
    local input = safeRead("*")
    if hashPassword(input) == config.swpass then
        return true
    else
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        local err = " Access Denied! "
        term.setCursorPos(math.floor((w - #err) / 2), iy + 1)
        term.write(err)
        sleep(1.2)
        os.reboot()
    end
end

local function refreshHeader()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.lightGray)
    term.write(string.rep(" ", w))
    for _, btn in ipairs(buttons) do
        if activePage == btn.target then
            term.setBackgroundColor(colors.blue)
            term.setTextColor(colors.white)
        else
            term.setBackgroundColor(colors.white)
            term.setTextColor(colors.black)
        end
        term.setCursorPos(btn.x, 1)
        term.write(btn.name)
    end
    term.setBackgroundColor(colors.blue)
    term.setCursorPos(1, 2)
    term.write(string.rep(" ", w))
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(1, h)
    term.write("(c) 2026 GGHJK UEFI - Secure Environment"..string.rep(" ",w))
end

local function clearContent()
    term.setBackgroundColor(colors.gray)
    for y = 3, h-1 do
        term.setCursorPos(1, y)
        term.clearLine()
    end
end

function DrawSystem()
    activePage = "System"
    clearContent()
    refreshHeader()
    term.setTextColor(colors.white)
    term.setCursorPos(2, 4) term.write("CraftOS:           " .. os.version())
    term.setCursorPos(2, 5) term.write("CC:Tweaked:        " .. cc_version)
    term.setCursorPos(2, 6) term.write("MC Version:        " .. mc_version)
    term.setCursorPos(2, 7) term.write("PC ID:             " .. os.getComputerID())
    term.setCursorPos(2, 8) term.write("PC Name:           " .. (os.getComputerLabel() or "Unnamed"))
    term.setCursorPos(2, 9) term.write("Firmware Version:  " .. (config.version or "N/A"))
    term.setCursorPos(2, 10) term.write("FW Rel. Date:      " .. (config.fwrd or "N/A"))
    term.setCursorPos(2, 11) term.write("GGHJK OS Version:  " .. gosver)
    term.setCursorPos(2, 12) term.write("Proccesor type:    GGHJK Core 5990")
    term.setCursorPos(2, 13) term.write("Proccesor Speed:   0.20GHz")
    term.setCursorPos(2, 14) term.write("Total Memory Size: 1032 MB") 
end

function DrawSecurity()
    activePage = "Security"
    clearContent()
    refreshHeader()
    term.setTextColor(colors.white)
    term.setCursorPos(2, 4) term.write("Supervisor PW: " .. ((config.swpass == "" or config.swpass == "fallback") and "None" or "PROTECTED"))
    term.setCursorPos(2, 5) term.write("PowerOn PW:    " .. (config.pwontr and "ENABLED" or "DISABLED"))
    term.setCursorPos(2, 6) term.write("Boot image:    " .. (config.secureboot and "DISABLED" or "ENABLED"))
    term.setTextColor(colors.yellow)
    term.setCursorPos(2, 8)  term.write("[ Toggle PowerOn Password ]")
    term.setCursorPos(2, 9)  term.write("[ Set Supervisor Password ]")
    term.setCursorPos(2, 10) term.write("[ Toggle Boot Images ]")
end

function DrawExit()
    activePage = "Exit"
    clearContent()
    refreshHeader()
    term.setTextColor(colors.white)
    term.setCursorPos(2, 4) term.write("[ Install latest GGHJK OS ]")
    term.setCursorPos(2, 5) term.write("[ Open Shell ]")
    term.setCursorPos(2, 6) term.write("[ Restart PC ]")
end
local function redraw()
    if activePage == "System" then DrawSystem()
    elseif activePage == "Security" then DrawSecurity()
    elseif activePage == "Exit" then DrawExit()
    elseif activePage == "Attestation Status" then  
    end
end

local function openUEFI()
    if askPassword("UEFI Setup") then
        term.setBackgroundColor(colors.gray)
        term.clear()
        redraw()
        while true do
            local event, button, x, y = os.pullEventRaw()
            if event == "mouse_click" then
                local clickedMenu = false
                for _, btn in ipairs(buttons) do
                    if y == 1 and x >= btn.x and x < (btn.x + btn.width) then
                        activePage = btn.target
                        redraw()
                        clickedMenu = true
                        break
                    end
                end
                if not clickedMenu then
                    if activePage == "Exit" then
                        if y == 4 then
                            term.clear() term.setCursorPos(1,1)
                            shell.run("mkdir /recovery/")
                            shell.run("wget https://raw.githubusercontent.com/MC-GGHJK/computercraft-ota-server/refs/heads/main/recovery/ota.recovery.start /recovery/ota.recovery.start")
                            shell.run("/recovery/ota.recovery.start")
                            break
                        elseif y == 5 then
                            term.setBackgroundColor(colors.black)
                            term.clear() term.setCursorPos(1,1)
                            shell.run("shell") break
                        elseif y == 6 then os.reboot() end
                    elseif activePage == "Security" then
                        if y == 8 then 
                            config.pwontr = not config.pwontr
                            saveConfig() DrawSecurity()
                        elseif y == 9 then
                            local ix, iy = drawNicePopup("Set Password", "New PW (empty = reset):")
                            local input = safeRead("*")
                            config.swpass = (input == "" and "fallback" or hashPassword(input))
                            saveConfig()
                            openUEFI()
                            break
                        elseif y == 10 then
                            config.secureboot = not config.secureboot
                            saveConfig() DrawSecurity()
                        end
                    end
                end
            end
        end
    end
end

local function drawSplash(path)
    local f = nOpen(path, "r")
    if not f then term.clear() return end
    local img = paintutils.parseImage(f.readAll())
    f.close()
    term.setBackgroundColor(colors.black)
    term.clear()
    local imgW = #img[1]
    paintutils.drawImage(img, math.floor((w - imgW) / 2) + 1, 3)
end

local function loading2s()
    local start = os.clock()
    local barWidth = math.floor(w * 0.5)
    local x = math.floor((w - barWidth) / 2) + 1

    while true do
        local elapsed = os.clock() - start
        if elapsed >= 2 then break end

        local progress = elapsed / 2
        if progress > 1 then progress = 1 end

        local filled = math.floor(barWidth * progress)

        term.setCursorPos(x, h - 2)
        term.setBackgroundColor(colors.cyan)
        term.write(string.rep(" ", filled))
        term.setBackgroundColor(colors.gray)
        term.write(string.rep(" ", barWidth - filled))

        rawSleep(0) -- místo sleep(0)
    end
end

local setupRequested = false
local function inputListener()
    local timer = os.startTimer(2)
    while true do
        local event, p1 = os.pullEventRaw()
        if event == "key" and p1 == keys.b then
            setupRequested = true
            break
        elseif event == "timer" and p1 == timer then break
        end
    end
end

term.setBackgroundColor(colors.black)
term.clear()
drawSplash("fw/assets/logo.nfp")
term.setCursorPos(math.floor((w - 22) / 2) + 1, h - 3)
term.setTextColor(colors.white)
term.setBackgroundColor(colors.black)
term.write("Press [B] To Open BIOS")

parallel.waitForAny(loading2s, inputListener)

if setupRequested then
    openUEFI()
else
    if config.pwontr then
        if not askPassword("System Boot") then os.reboot() end
    end
    term.setBackgroundColor(colors.black)
    term.clear() term.setCursorPos(1,1)
    if fs.exists("/boot.img") then shell.run("/boot.img")
    else shell.run("shell") end
end
