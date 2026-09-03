label = "Periferie"
color = "colors.green"
desc = "Pripojena zarizeni a jejich typ"

local w, h = term.getSize()

local function fill(x1, y1, x2, y2, bg, fg, ch)
    ch = ch or " "
    term.setBackgroundColor(bg)
    if fg then term.setTextColor(fg) end
    for y = y1, y2 do
        term.setCursorPos(x1, y)
        term.write(string.rep(ch, x2 - x1 + 1))
    end
end

local scroll = 0

local function getPeripheralList()
    local list = {}
    if not peripheral then return list end
    local names = peripheral.getNames()
    for _, name in ipairs(names) do
        local ptype = peripheral.getType(name) or "unknown"
        local isWireless = false
        local ok, wrapped = pcall(peripheral.wrap, name)
        local extra = ""
        if ok and wrapped then
            if ptype == "modem" and wrapped.isWireless then
                local wok, wireless = pcall(wrapped.isWireless)
                if wok then extra = wireless and "(wireless)" or "(wired)" end
            end
        end
        table.insert(list, { name = name, ptype = ptype, extra = extra })
    end
    return list
end

local function draw()
    fill(1, 3, w, h, colors.gray)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(3, 3)
    term.write("Pripojene periferie")
    fill(2, 4, w - 1, 4, colors.gray, colors.lightGray, "\140")

    local list = getPeripheralList()

    if #list == 0 then
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, 6)
        term.write("Zadne periferie nenalezeny.")
        return
    end

    local visibleRows = h - 6
    for i = 1, visibleRows do
        local idx = i + scroll
        local p = list[idx]
        local y = 6 + i - 1
        if p then
            term.setBackgroundColor(colors.lightGray)
            term.setTextColor(colors.black)
            fill(2, y, w - 1, y, colors.lightGray)
            term.setCursorPos(3, y)
            term.write(p.name)
            term.setTextColor(colors.gray)
            local infoText = p.ptype .. " " .. p.extra
            term.setCursorPos(w - #infoText - 2, y)
            term.write(infoText)
        end
    end

    if #list > visibleRows then
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(3, h - 1)
        term.write("Scroll: " .. (scroll + 1) .. "-" .. math.min(scroll + visibleRows, #list) .. "/" .. #list)
    end
end

draw()
local refreshTimer = os.startTimer(2)

while true do
    local ev, p1, p2, p3 = os.pullEvent()
    if ev == "timer" and p1 == refreshTimer then
        draw()
        refreshTimer = os.startTimer(2)
    elseif ev == "mouse_click" then
        if p3 == 1 and p2 >= 2 and p2 <= 7 then break end
    elseif ev == "mouse_scroll" then
        local list = getPeripheralList()
        local visibleRows = h - 6
        local maxScroll = math.max(0, #list - visibleRows)
        scroll = math.max(0, math.min(maxScroll, scroll + p1))
        draw()
    end
end
