label = "System Info"
color = "colors.blue"
desc = "Info o systemu"

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

local function row(y, label_, value, labelFg, valueFg)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(labelFg or colors.lightGray)
    term.setCursorPos(3, y)
    term.write(label_)
    term.setTextColor(valueFg or colors.white)
    term.setCursorPos(20, y)
    term.write(tostring(value))
end

local function humanSize(bytes)
    if not bytes then return "n/a" end
    local units = { "B", "KB", "MB", "GB" }
    local i = 1
    while bytes >= 1024 and i < #units do
        bytes = bytes / 1024
        i = i + 1
    end
    return string.format("%.1f %s", bytes, units[i])
end

local function formatUptime(seconds)
    local s = math.floor(seconds)
    local hrs = math.floor(s / 3600)
    local mins = math.floor((s % 3600) / 60)
    local secs = s % 60
    return string.format("%02d:%02d:%02d", hrs, mins, secs)
end

local startClock = os.clock()

local function draw()
    fill(1, 3, w, h, colors.gray)

    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(3, 3)
    term.write("System Information")
    fill(2, 4, w - 1, 4, colors.gray, colors.lightGray, "\140")

    local label = os.getComputerLabel() or "(none)"
    local id = os.getComputerID()
    local ver = os.version and os.version() or "unknown"

    local free = fs.getFreeSpace and fs.getFreeSpace("/") or nil
    local cap = fs.getCapacity and fs.getCapacity("/") or nil

    row(6,  "Computer ID:",     id)
    row(7,  "Computer Label:",  label)
    row(8,  "CC Version:",      ver)
    row(9,  "Firmware:",        "GGHJK UEFI v3.0")
    row(11, "Free storage:",    humanSize(free))
    row(12, "Total storage:",   humanSize(cap))
    row(13, "Current time:",    textutils.formatTime(os.time(), true))
    row(14, "Current day:",     tostring(os.day and os.day() or "n/a"))

    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.lightGray)
    term.setCursorPos(3, h - 1)
    term.write("Auto-refreshing... click top-left to go back")
end

draw()
local refreshTimer = os.startTimer(1)

while true do
    local ev, p1, p2, p3 = os.pullEvent()
    if ev == "timer" and p1 == refreshTimer then
        draw()
        refreshTimer = os.startTimer(1)
    elseif ev == "mouse_click" then
        if p3 == 1 and p2 >= 2 and p2 <= 7 then break end
    end
end
