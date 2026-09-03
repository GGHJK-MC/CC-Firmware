local w, h = term.getSize()

local SECCFG = "/fw/seccfg/"
local DEFAULT_LOGO_TIME = 2
local DEFAULT_ENTRIES = {
    { name = "Boot 1", path = "/boot1", priority = 100 },
}

-- Načtení popup modulu
local popup = require("api.popup")

local function getRawOpen()
    for i = 1, 50 do
        local n, v = debug.getupvalue(fs.open, i)
        if n == "nOpen" then return v end
        if n == nil then break end
    end
    return fs.open
end
local nOpen = getRawOpen()

local function getRawMakeDir()
    for i = 1, 50 do
        local n, v = debug.getupvalue(fs.makeDir, i)
        if n == "nMakeDir" then return v end
        if n == nil then break end
    end
    return nil
end
local nMakeDir = getRawMakeDir()

local function ensureSeccfgDir()
    if not fs.exists(SECCFG) and nMakeDir then
        nMakeDir(SECCFG)
    end
end

local function readSeccfg(path)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local c = f.readAll()
    f.close()
    return c
end

local function writeSeccfg(path, content)
    ensureSeccfgDir()
    local f = nOpen(path, "w")
    if not f then return false end
    f.write(content)
    f.close()
    return true
end

local function loadLogoTime()
    local c = readSeccfg(SECCFG .. "logotime")
    local n = c and tonumber((c:gsub("%s+", "")))
    if n and n >= 0 and n <= 60 then return n end
    return DEFAULT_LOGO_TIME
end

local function loadBootMenuMode()
    local c = readSeccfg(SECCFG .. "bootmenu")
    if c then
        c = c:gsub("%s+", "")
        if c == "always" or c == "auto" then return c end
    end
    return "auto"
end

local function loadBootEntries()
    local c = readSeccfg(SECCFG .. "bootentries")
    if c then
        local ok, data = pcall(textutils.unserialize, c)
        if ok and type(data) == "table" and #data > 0 then
            local clean = {}
            for _, e in ipairs(data) do
                if type(e) == "table" and type(e.path) == "string"
                   and type(e.name) == "string" and type(e.priority) == "number" then
                    table.insert(clean, e)
                end
            end
            if #clean > 0 then return clean end
        end
    end
    return DEFAULT_ENTRIES
end

local function saveBootEntries(entries)
    return writeSeccfg(SECCFG .. "bootentries", textutils.serialize(entries))
end

_G.fwBootAPI = {
    loadLogoTime = loadLogoTime,
    loadBootMenuMode = loadBootMenuMode,
    loadBootEntries = loadBootEntries,
    saveBootEntries = saveBootEntries,
    seccfgDir = SECCFG,
}

local function sortedEntries()
    local entries = loadBootEntries()
    table.sort(entries, function(a, b) return a.priority > b.priority end)
    return entries
end

local function fill(x1, y1, x2, y2, bg)
    term.setBackgroundColor(bg)
    local s = string.rep(" ", x2 - x1 + 1)
    for y = y1, y2 do
        term.setCursorPos(x1, y)
        term.write(s)
    end
end

local function clearScreen(bg)
    bg = bg or colors.black
    term.setBackgroundColor(bg)
    term.clear()
end

local function center(y, bg, fg, text)
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    term.setCursorPos(math.floor((w - #text) / 2) + 1, y)
    term.write(text)
end

local function showLogoAndWaitForB(duration)
    clearScreen(colors.black)

    local img = nil
    if fs.exists("/fw/assets/logo.nfp") then
        local ok, loaded = pcall(paintutils.loadImage, "/fw/assets/logo.nfp")
        if ok then img = loaded end
    end

    if img then
        local imgW = #img[1]
        local imgH = #img
        local ix = math.floor((w - imgW) / 2) + 1
        local iy = math.floor((h - imgH) / 2) + 1
        paintutils.drawImage(img, ix, iy)
    else
        center(math.floor(h / 2), colors.black, colors.white, "GGHJK UEFI")
    end

    center(h - 1, colors.black, colors.gray, "Press [B] for boot menu")

    local pressedB = false
    local timerId = os.startTimer(duration)
    while true do
        local ev, p1 = os.pullEvent()
        if ev == "timer" and p1 == timerId then
            break
        elseif ev == "key" and p1 == keys.b then
            pressedB = true
            break
        elseif ev == "char" and p1 == "b" then
            pressedB = true
            break
        end
    end
    return pressedB
end

local sha = dofile("/fw/api/sha256")

local function checkAdminPassword()
    local passPath = SECCFG .. "passhash"
    if not fs.exists(passPath) then
        return true
    end

    local stored = readSeccfg(passPath)
    if not stored then return true end

    -- Kontrola prázdného hesla (ignoruje bílé znaky a mezery)
    stored = stored:gsub("%s+", "")
    if stored == "" then
        return true
    end

    -- Použití popup API
    if popup and type(popup.input) == "function" then
        while true do
            local input = popup.input("Administrator Password", "", "Enter password:")

            -- Uživatel stiskl Cancel / zrušil popup
            if not input then
                return false
            end

            if sha.verify(input, stored) then
                return true
            else
                if popup.message then
                    popup.message("Error", "Incorrect password!")
                end
            end
        end
    else
        -- Fallback pro případ, že popup API selže
        clearScreen(colors.black)
        center(math.floor(h / 2) - 2, colors.black, colors.white, "Administrator password required")
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        local px = math.floor((w - 20) / 2) + 1
        local py = math.floor(h / 2)
        term.setCursorPos(px, py)
        term.write("Password: ")
        term.setCursorBlink(true)

        local input = ""
        while true do
            local ev, p1 = os.pullEvent()
            if ev == "char" then
                input = input .. p1
                term.setCursorPos(px + 10, py)
                term.write(string.rep("*", #input))
            elseif ev == "key" then
                if p1 == keys.backspace and #input > 0 then
                    input = input:sub(1, -2)
                    term.setCursorPos(px + 10, py)
                    term.write(string.rep("*", #input) .. " ")
                elseif p1 == keys.enter then
                    term.setCursorBlink(false)
                    if sha.verify(input, stored) then
                        return true
                    else
                        center(py + 2, colors.black, colors.red, "Incorrect password")
                        sleep(1.2)
                        return false
                    end
                end
            end
        end
    end
end

-- Příprava globálního prostředí těsně před bootem
local function cleanupBeforeBoot()
    -- Obnovení odchytávání terminate (Ctrl+T)
    if os.pullEventRaw then
        os.pullEvent = os.pullEventRaw
    end

    -- Odstranění záchytných globálních proměnných
    _G.nopen = nil
    _G.fw_protected = nil
    _G.seccfg_lock = nil
    _G.fwBootAPI = nil

    -- Obnovení systémových funkcí do původního stavu
    if nOpen then fs.open = nOpen end
    if nMakeDir then fs.makeDir = nMakeDir end
end

local function tryRunEntry(entry)
    if not fs.exists(entry.path) then return false end
    local f = fs.open(entry.path, "r")
    if not f then return false end
    local content = f.readAll()
    f.close()

    local fn, err = load(content, "=" .. entry.name, "t", _ENV)
    if not fn then return false end

    -- Obnovení prostředí před spuštěním OS
    cleanupBeforeBoot()

    clearScreen(colors.black)
    local ok, runErr = pcall(fn)

    return true
end

local function runFirstAvailableEntry(entries)
    for _, e in ipairs(entries) do
        if tryRunEntry(e) then return true end
    end
    return false
end

local function chooseBootEntry(entries)
    local sel = 1
    local scroll = 0
    local listY0 = 4
    local visibleRows = h - listY0 - 2

    local function draw()
        clearScreen(colors.black)
        center(2, colors.black, colors.white, "Select boot entry")

        for i = 1, visibleRows do
            local idx = i + scroll
            local e = entries[idx]
            local y = listY0 + i - 1
            if e then
                local isSel = (idx == sel)
                term.setBackgroundColor(isSel and colors.lightBlue or colors.black)
                term.setTextColor(isSel and colors.black or colors.white)
                term.setCursorPos(3, y)
                term.write(string.rep(" ", w - 4))
                term.setCursorPos(3, y)
                term.write(e.name .. "  (" .. e.path .. ")")
            end
        end

        if #entries > visibleRows then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.gray)
            term.setCursorPos(2, h - 1)
            term.write("[Up/Down scroll, Enter select]  " .. sel .. "/" .. #entries)
        else
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.gray)
            term.setCursorPos(2, h - 1)
            term.write("[Up/Down select, Enter confirm]")
        end
    end

    local function ensureVisible()
        if sel <= scroll then scroll = sel - 1 end
        if sel > scroll + visibleRows then scroll = sel - visibleRows end
        if scroll < 0 then scroll = 0 end
    end

    draw()
    while true do
        local ev, p1 = os.pullEvent()
        if ev == "key" then
            if p1 == keys.up then
                sel = (sel == 1) and #entries or (sel - 1)
                ensureVisible(); draw()
            elseif p1 == keys.down then
                sel = (sel % #entries) + 1
                ensureVisible(); draw()
            elseif p1 == keys.enter then
                return entries[sel]
            end
        elseif ev == "mouse_scroll" then
            scroll = math.max(0, math.min(#entries - visibleRows, scroll + p1))
            draw()
        end
    end
end

local function showFwError(titleSuffix, lines)
    clearScreen(colors.black)

    local f = fs.open("/fw/assets/err.nfp", "r")
    if f then
        local ok, img = pcall(paintutils.parseImage, f.readAll())
        f.close()
        if ok and img and #img > 0 then
            local imgW = (type(img[1]) == "table") and #img[1] or 0
            paintutils.drawImage(img, math.max(1, math.floor((w - imgW) / 2) + 1), 2)
        end
    end

    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.white)
    term.setCursorPos(1, 1)
    term.write(string.rep(" ", w))
    term.setCursorPos(1, 1)
    term.write("  [X] GGHJK UEFI  |  " .. titleSuffix)

    term.setBackgroundColor(colors.black)

    for i, line in ipairs(lines) do
        center(7 + i, colors.black, line.fg or colors.white, line.text)
    end
end

local function bootMenu()
    local items = {
        "Continue boot",
        "Reboot",
        "Poweroff",
        "Enter setup utility",
    }
    local sel = 1

    local function draw()
        clearScreen(colors.black)
        center(2, colors.black, colors.lightBlue, "BOOT MENU")
        for i, label in ipairs(items) do
            local y = 5 + (i - 1) * 2
            local isSel = (i == sel)
            term.setBackgroundColor(isSel and colors.lightBlue or colors.black)
            term.setTextColor(isSel and colors.black or colors.white)
            term.setCursorPos(4, y)
            term.write(string.rep(" ", w - 8))
            term.setCursorPos(4, y)
            term.write(label)
        end
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.gray)
        term.setCursorPos(2, h - 1)
        term.write("[Up/Down, Enter]")
    end

    draw()
    while true do
        local ev, p1 = os.pullEvent()
        if ev == "key" then
            if p1 == keys.up then
                sel = (sel == 1) and #items or (sel - 1)
                draw()
            elseif p1 == keys.down then
                sel = (sel % #items) + 1
                draw()
            elseif p1 == keys.enter then
                local choice = items[sel]

                if choice == "Continue boot" then
                    local entries = sortedEntries()
                    if #entries > 1 then
                        local picked = chooseBootEntry(entries)
                        if tryRunEntry(picked) then return end

                        runFirstAvailableEntry(entries)
                        return
                    else
                        runFirstAvailableEntry(entries)
                        return
                    end

                elseif choice == "Reboot" then
                    os.reboot()

                elseif choice == "Poweroff" then
                    os.shutdown()

                elseif choice == "Enter setup utility" then
                    if checkAdminPassword() then
                        if fs.exists("/fw/fwui.lua") then
                            local ok, err = pcall(shell.run, "/fw/fwui.lua")
                            if not ok then
                                showFwError("Setup Error", {
                                    { text = "fwui.lua crashed", fg = colors.red },
                                    { text = tostring(err), fg = colors.lightGray },
                                })
                                os.pullEvent("key")
                            end
                        else
                            showFwError("Setup Error", {
                                { text = "/fw/fwui.lua not found", fg = colors.red },
                                { text = "Setup utility is missing or corrupt.", fg = colors.lightGray },
                            })
                            os.pullEvent("key")
                        end
                    end
                    draw()
                end
            end
        end
    end
end

local logoTime = loadLogoTime()
local bootMenuMode = loadBootMenuMode()

local pressedB = showLogoAndWaitForB(logoTime)

if pressedB then
    bootMenu()
elseif bootMenuMode == "always" then
    local entries = sortedEntries()
    if #entries > 1 then
        local picked = chooseBootEntry(entries)
        if not tryRunEntry(picked) then
            runFirstAvailableEntry(entries)
        end
    else
        runFirstAvailableEntry(entries)
    end
else
    local entries = sortedEntries()
    if not runFirstAvailableEntry(entries) then
        showFwError("Boot Error", {
            { text = "No bootable entry found!", fg = colors.red },
            { text = "Press any key for boot menu...", fg = colors.lightGray },
        })
        os.pullEvent("key")
        bootMenu()
    end
end