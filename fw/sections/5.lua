label = "Boot Options"
color = "colors.orange"
desc = "Boot zaznamy, priorita, doba loga"
protected = true

local w, h = term.getSize()

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

local SECCFG = "/fw/seccfg/"

local function ensureSeccfgDir()
    if not fs.exists(SECCFG) and nMakeDir then
        nMakeDir(SECCFG)
    end
end

local function fill(x1, y1, x2, y2, bg, fg, ch)
    ch = ch or " "
    term.setBackgroundColor(bg)
    if fg then term.setTextColor(fg) end
    for y = y1, y2 do
        term.setCursorPos(x1, y)
        term.write(string.rep(ch, x2 - x1 + 1))
    end
end

local DEFAULT_ENTRIES = {
    { name = "Boot 1", path = "/boot1", priority = 100 },
}

local function readRaw(path)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local c = f.readAll()
    f.close()
    return c
end

local function loadBootEntries()
    local c = readRaw(SECCFG .. "bootentries")
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

    local copy = {}
    for _, e in ipairs(DEFAULT_ENTRIES) do
        table.insert(copy, { name = e.name, path = e.path, priority = e.priority })
    end
    return copy
end

local function saveBootEntries(entries)
    ensureSeccfgDir()
    local f = nOpen(SECCFG .. "bootentries", "w")
    if not f then return false end
    f.write(textutils.serialize(entries))
    f.close()
    return true
end

local function loadLogoTime()
    local c = readRaw(SECCFG .. "logotime")
    local n = c and tonumber((c:gsub("%s+", "")))
    if n and n >= 0 and n <= 60 then return n end
    return 2
end

local function saveLogoTime(n)
    ensureSeccfgDir()
    local f = nOpen(SECCFG .. "logotime", "w")
    if not f then return false end
    f.write(tostring(n))
    f.close()
    return true
end

local function loadBootMenuMode()
    local c = readRaw(SECCFG .. "bootmenu")
    if c then
        c = c:gsub("%s+", "")
        if c == "always" or c == "auto" then return c end
    end
    return "auto"
end

local function saveBootMenuMode(mode)
    ensureSeccfgDir()
    local f = nOpen(SECCFG .. "bootmenu", "w")
    if not f then return false end
    f.write(mode)
    f.close()
    return true
end

local entries = loadBootEntries()
local logoTime = loadLogoTime()
local bootMenuMode = loadBootMenuMode()

local sel = 1
local scroll = 0

local function textInput(prompt, default)
    fill(1, h - 4, w, h - 2, colors.lightGray)
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.setCursorPos(3, h - 4)
    term.write(prompt)
    fill(3, h - 3, w - 3, h - 3, colors.white)
    term.setCursorPos(3, h - 3)
    term.setCursorBlink(true)

    local input = default or ""
    term.write(input)
    while true do
        local ev, p1 = os.pullEvent()
        if ev == "char" then
            input = input .. p1
            term.setCursorPos(3, h - 3)
            term.write(input .. " ")
        elseif ev == "key" then
            if p1 == keys.backspace and #input > 0 then
                input = input:sub(1, -2)
                term.setCursorPos(3, h - 3)
                term.write(input .. "  ")
            elseif p1 == keys.enter then
                term.setCursorBlink(false)
                return input
            elseif p1 == keys.escape then
                term.setCursorBlink(false)
                return nil
            end
        end
    end
end

local function showMsg(msg, bg, fg)
    fill(1, h - 2, w, h - 2, bg or colors.black)
    term.setBackgroundColor(bg or colors.black)
    term.setTextColor(fg or colors.white)
    term.setCursorPos(3, h - 2)
    term.write(msg)
    sleep(1.2)
end

local function addEntry()
    local name = textInput("Boot entry name:", "")
    if not name or name == "" then return end
    local path = textInput("Path (e.g. /boot1):", "/boot" .. tostring(#entries + 1))
    if not path or path == "" then return end
    local prioStr = textInput("Priority (higher = boots first):", "50")
    local prio = tonumber(prioStr)
    if not prio then
        showMsg("Priority must be a number", colors.red)
        return
    end
    table.insert(entries, { name = name, path = path, priority = prio })
    saveBootEntries(entries)
    showMsg("Boot entry added", colors.lime)
end

local function renameEntry(idx)
    local e = entries[idx]
    local name = textInput("New name:", e.name)
    if not name or name == "" then return end
    e.name = name
    saveBootEntries(entries)
end

local function rePathEntry(idx)
    local e = entries[idx]
    local path = textInput("New path:", e.path)
    if not path or path == "" then return end
    e.path = path
    saveBootEntries(entries)
end

local function reprioritizeEntry(idx)
    local e = entries[idx]
    local prioStr = textInput("New priority:", tostring(e.priority))
    local prio = tonumber(prioStr)
    if not prio then
        showMsg("Priority must be a number", colors.red)
        return
    end
    e.priority = prio
    saveBootEntries(entries)
end

local function deleteEntry(idx)
    if #entries <= 1 then
        showMsg("Cannot delete the last boot entry", colors.red)
        return
    end
    table.remove(entries, idx)
    saveBootEntries(entries)
    if sel > #entries then sel = #entries end
end

local ENTRY_Y0 = 7
local VISIBLE = 4

local function sortedForDisplay()

    local copy = {}
    for i, e in ipairs(entries) do copy[i] = e end
    table.sort(copy, function(a, b) return a.priority > b.priority end)
    return copy
end

local function draw()
    fill(1, 3, w, h, colors.gray)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(3, 3)
    term.write("Boot Options")
    fill(2, 4, w - 1, 4, colors.gray, colors.lightGray, "\140")

    term.setTextColor(colors.lightGray)
    term.setCursorPos(3, 5)
    term.write("Logo display time:")
    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.white)
    term.setCursorPos(24, 5)
    term.write(" - ")
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.setCursorPos(28, 5)
    term.write(string.format(" %2ds ", logoTime))
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.white)
    term.setCursorPos(34, 5)
    term.write(" + ")

    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.lightGray)
    term.setCursorPos(3, 6)
    term.write("Boot menu:")
    local modeLabel = (bootMenuMode == "always")
        and " Always show "
        or " Auto (press B) "
    term.setBackgroundColor(colors.lightBlue)
    term.setTextColor(colors.black)
    term.setCursorPos(14, 6)
    term.write(modeLabel)

    local displayList = sortedForDisplay()
    for i = 1, VISIBLE do
        local idx = i + scroll
        local e = displayList[idx]
        local y = ENTRY_Y0 + (i - 1) * 2
        if e then
            local isSel = (idx == sel)
            fill(2, y, w - 1, y + 1, isSel and colors.lightBlue or colors.lightGray)
            term.setTextColor(colors.black)
            term.setCursorPos(3, y)
            term.write(e.name)
            term.setTextColor(colors.gray)
            term.setCursorPos(3, y + 1)
            term.write(e.path .. "  (priority " .. e.priority .. ")")
        end
    end

    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.lightGray)
    local hintY = ENTRY_Y0 + VISIBLE * 2 + 1
    if hintY <= h - 1 then
        term.setCursorPos(3, hintY)
        term.write("[N]ew  [R]ename  [P]ath  [O]rder  [Del]ete")
    end
end

draw()

while true do
    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "mouse_click" then
        local mx, my = p2, p3

        if my == 1 and mx >= 2 and mx <= 7 then
            break
        elseif my == 5 and mx >= 24 and mx <= 26 then
            logoTime = math.max(0, logoTime - 1)
            saveLogoTime(logoTime)
            draw()
        elseif my == 5 and mx >= 34 and mx <= 36 then
            logoTime = math.min(60, logoTime + 1)
            saveLogoTime(logoTime)
            draw()
        elseif my == 6 and mx >= 14 then
            bootMenuMode = (bootMenuMode == "always") and "auto" or "always"
            saveBootMenuMode(bootMenuMode)
            draw()
        else
            local displayList = sortedForDisplay()
            for i = 1, VISIBLE do
                local idx = i + scroll
                local y = ENTRY_Y0 + (i - 1) * 2
                if displayList[idx] and (my == y or my == y + 1) then
                    sel = idx
                    draw()
                    break
                end
            end
        end

    elseif ev == "key" then
        local displayList = sortedForDisplay()
        if p1 == keys.n then
            addEntry()
            draw()
        elseif p1 == keys.r and displayList[sel] then
            renameEntry(sel)
            draw()
        elseif p1 == keys.p and displayList[sel] then
            rePathEntry(sel)
            draw()
        elseif p1 == keys.o and displayList[sel] then
            reprioritizeEntry(sel)
            draw()
        elseif p1 == keys.delete and displayList[sel] then
            deleteEntry(sel)
            draw()
        elseif p1 == keys.up then
            sel = (sel == 1) and #entries or (sel - 1)
            if sel <= scroll then scroll = math.max(0, sel - 1) end
            draw()
        elseif p1 == keys.down then
            sel = (sel % #entries) + 1
            if sel > scroll + VISIBLE then scroll = sel - VISIBLE end
            draw()
        end
    end
end
