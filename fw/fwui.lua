local _nPull = os.pullEventRaw
os.pullEventRaw = function(f)
    while true do
        local e = {_nPull(f)}
        if e[1] ~= "terminate" then
            return table.unpack(e)
        end
    end
end
os.pullEvent = function(f) return os.pullEventRaw(f) end

local function getRawOpen()
    for i = 1, 50 do
        local n, v = debug.getupvalue(fs.open, i)
        if n == "nOpen" then return v end
        if n == nil then break end
    end
    return fs.open
end
local nOpen = getRawOpen()

local sha = dofile("/fw/api/sha256")

local C = {
    bg      = colors.black,
    bar     = colors.gray,
    barTxt  = colors.white,
    accent  = colors.cyan,
    divider = colors.gray,
    panel   = colors.lightGray,
    panelDk = colors.gray,
    btnHl   = colors.white,
    arrow   = colors.gray,
    danger  = colors.red,
    ok      = colors.lime,
    warn    = colors.orange,
}

local W, H = term.getSize()
local function sync() W, H = term.getSize() end

local function fill(x1, y1, x2, y2, bg, fg, ch)
    if x1 > x2 or y1 > y2 then return end
    ch = ch or " "
    term.setBackgroundColor(bg)
    if fg then term.setTextColor(fg) end
    local s = string.rep(ch, x2 - x1 + 1)
    for y = y1, y2 do
        term.setCursorPos(x1, y)
        term.write(s)
    end
end

local function put(x, y, bg, fg, s)
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    term.setCursorPos(x, y)
    term.write(s)
end

local function center(y, bg, fg, s)
    put(math.floor((W - #s) / 2) + 1, y, bg, fg, s)
end

local FW_TITLE = "GGHJK UEFI"

local function drawHeader(left, title, xo)
    xo = xo or 0
    fill(1 + xo, 1, W + xo, 1, C.bar)
    put(2 + xo, 1, C.bar, C.accent, "\4 ")
    put(4 + xo, 1, C.bar, C.barTxt, left or FW_TITLE)
    if title then
        local tx = math.floor((W - #title) / 2) + 1 + xo
        put(tx, 1, C.bar, C.accent, title)
    end
    local t = textutils.formatTime(os.time(), true)
    put(W - #t - 1 + xo, 1, C.bar, C.panelDk, t)
    fill(1 + xo, 2, W + xo, 2, C.bg, C.accent, "\140")
end

local function drawSubHeader(title, xo)
    xo = xo or 0
    fill(1 + xo, 1, W + xo, 1, C.bar)
    put(2 + xo, 1, C.bar, C.accent, "< Zpet")
    local tx = math.floor((W - #title) / 2) + 1 + xo
    put(tx, 1, C.bar, C.barTxt, title)
    fill(1 + xo, 2, W + xo, 2, C.bg, C.accent, "\140")
end

local apps = {}
local scroll = 0

local function loadApps()
    apps = {}
    local dir = "/fw/sections/"
    if not fs.exists(dir) then return end
    for _, fname in ipairs(fs.list(dir)) do
        if fname:sub(-4) == ".lua" then
            local num = tonumber(fname:sub(1, -5))
            if num and num >= 1 and num <= 99 then
                local path = fs.combine(dir, fname)
                local f = fs.open(path, "r")
                if f then
                    local l1 = f.readLine() or ""
                    local l2 = f.readLine() or ""
                    local l3 = f.readLine() or ""
                    local l4 = f.readLine() or ""
                    f.close()
                    local lbl = l1:match('label%s*=%s*["\']([^"\']+)["\']') or fname
                    local col = l2:match('color%s*=%s*["\']colors%.([%a]+)["\']')
                    local clr = (col and colors[col]) or colors.blue
                    local dsc = l3:match('desc%s*=%s*["\']([^"\']+)["\']') or ""
                    local prot = l4:match('protected%s*=%s*(true)') ~= nil
                    table.insert(apps, {
                        order     = num,
                        label     = lbl,
                        path      = path,
                        color     = clr,
                        desc      = dsc,
                        protected = prot
                    })
                end
            end
        end
    end
    table.sort(apps, function(a, b) return a.order < b.order end)
end

local function drawButton(i, app, sel, xo)
    xo = xo or 0
    local y = 3 + (i - 1) * 3 - scroll
    if y + 1 < 3 or y > H then return end
    local bg = sel and C.btnHl or C.panel
    local fg = colors.black
    local dFg = C.panelDk
    fill(2 + xo, y, W - 2 + xo, y + 1, bg)
    fill(2 + xo, y, 5 + xo, y + 1, app.color)

    local lbl = app.label
    if app.protected then lbl = "\7 " .. lbl end
    put(7 + xo, y, bg, fg, lbl:sub(1, W - 11))
    if app.desc ~= "" then put(7 + xo, y + 1, bg, dFg, app.desc:sub(1, W - 11)) end
    put(W - 2 + xo, y, bg, C.arrow, ">")
    put(W - 2 + xo, y + 1, bg, C.arrow, " ")
    if y + 2 <= H then fill(2 + xo, y + 2, W - 2 + xo, y + 2, C.bg, C.panelDk, "\140") end
end

local function drawScrollbar()
    local total = #apps * 3
    local viewH = H - 2
    if total <= viewH then return end
    local barH = math.max(1, math.floor(viewH / total * viewH))
    local maxS = total - viewH
    local barY = 3 + math.floor((scroll / maxS) * (viewH - barH))
    fill(W, 3, W, H, C.panelDk)
    fill(W, barY, W, barY + barH - 1, C.accent)
end

local function drawMain(xo, sel)
    xo = xo or 0
    sync()
    fill(1 + xo, 1, W + xo, H, C.bg)
    drawHeader(FW_TITLE, nil, xo)
    for i, app in ipairs(apps) do
        drawButton(i, app, i == sel, xo)
    end
    drawScrollbar()
end

local function slideIn(title, sel)
    for x = 0, W, 3 do
        drawMain(-x, sel)
        if W - x + 1 <= W then
            fill(W - x + 1, 1, W, H, C.bg)
            drawSubHeader(title, W - x)
        end
        sleep(0.01)
    end
    fill(1, 1, W, H, C.bg)
    drawSubHeader(title, 0)
end

local function slideOut()
    for x = 0, W, 3 do
        fill(1, 1, W, H, C.bg)
        drawMain(-W + x)
        if x < W then
            fill(x + 1, 1, W, H, C.bg)
        end
        sleep(0.01)
    end
    drawMain(0)
end

local function readHash(path)
    local f = nOpen(path, "r")
    if not f then return nil end
    local c = f.readAll()
    f.close()
    return (c and c:gsub("%s+", "") ~= "") and c:gsub("%s+", "") or nil
end

local function promptPassword(title)
    sync()
    local bx = math.floor((W - 34) / 2) + 1
    local by = math.floor((H - 8) / 2)

    fill(bx + 1, by + 1, bx + 35, by + 9, C.panelDk)
    fill(bx, by, bx + 34, by + 8, C.panel)
    fill(bx, by, bx + 34, by, C.bar, C.accent)
    put(bx + 2, by, C.bar, C.accent, "* ")
    put(bx + 4, by, C.bar, C.barTxt, title:sub(1, 28))
    fill(bx, by + 1, bx + 34, by + 1, C.panel, C.panelDk, "\140")
    put(bx + 2, by + 3, C.panel, colors.black, "FW heslo:")
    fill(bx + 2, by + 5, bx + 32, by + 5, colors.white)

    fill(bx + 2, by + 7, bx + 9, by + 7, C.panelDk, colors.white)
    put(bx + 2, by + 7, C.panelDk, colors.white, " Zrusit")
    fill(bx + 11, by + 7, bx + 21, by + 7, C.accent, colors.black)
    put(bx + 11, by + 7, C.accent, colors.black, "    OK    ")
    term.setCursorBlink(true)

    local pw = ""
    while true do
        fill(bx + 2, by + 5, bx + 32, by + 5, colors.white)
        put(bx + 2, by + 5, colors.white, colors.black, string.rep("*", #pw) .. string.rep(" ", 30 - #pw))
        term.setCursorPos(bx + 2 + #pw, by + 5)
        local ev, p1, p2, p3 = os.pullEventRaw()
        if ev == "char" and #pw < 28 then
            pw = pw .. p1
        elseif ev == "key" then
            if p1 == keys.backspace and #pw > 0 then
                pw = pw:sub(1, -2)
            elseif p1 == keys.enter then
                term.setCursorBlink(false)
                return pw
            elseif p1 == keys.escape then
                term.setCursorBlink(false)
                return nil
            end
        elseif ev == "mouse_click" then
            local mx, my = p2, p3
            if my == by + 7 and mx >= bx + 2 and mx <= bx + 9 then
                term.setCursorBlink(false)
                return nil
            end
            if my == by + 7 and mx >= bx + 11 and mx <= bx + 21 then
                term.setCursorBlink(false)
                return pw
            end
        end
    end
end

local function checkFWPass()
    local h = readHash("/fw/seccfg/passhash")
    if not h then return true end
    local pw = promptPassword("Overeni FW")
    if not pw then return false end
    return sha.verify(pw, h)
end

local apiCache = {}
local secEnv

local function fwRequire(name)
    if apiCache[name] then return apiCache[name] end
    local mod = name:match("^fw%.api%.([%w_]+)$")
    if not mod then error("require: povolen jen fw.api.*", 2) end
    local path = "/fw/api/" .. mod
    if not fs.exists(path) then path = path .. ".lua" end
    if not fs.exists(path) then error("require: nenalezen: /fw/api/" .. mod, 2) end
    local fn, err = loadfile(path, "t", secEnv)
    if not fn then error("require: " .. tostring(err), 2) end
    local r = fn()
    apiCache[name] = r ~= nil and r or true
    return apiCache[name]
end

secEnv = setmetatable({
    os = setmetatable({
        pullEventRaw = os.pullEventRaw,
        pullEvent    = os.pullEvent,
    }, { __index = os }),
    require = fwRequire,
    _nOpen  = nOpen,
    sha256  = sha.hash,
}, { __index = _G })
secEnv._ENV = secEnv

local function runSection(app)
    if app.protected then
        drawMain(0)
        if not checkFWPass() then
            drawMain(0)
            return
        end
    end

    slideIn(app.label, nil)
    fill(1, 3, W, H, C.bg)

    local fn, err = loadfile(app.path, "t", secEnv)
    if not fn then
        put(2, 4, C.bg, C.danger, "[Chyba nacteni]")
        put(2, 5, C.bg, colors.lightGray, tostring(err):sub(1, W - 4))
        put(2, 7, C.bg, C.panelDk, "Klikni pro navrat...")
        os.pullEvent("mouse_click")
        slideOut()
        return
    end

    local ok, errmsg = pcall(fn)
    if not ok then
        fill(1, 3, W, H, C.bg)
        put(2, 4, C.bg, C.danger, "[Chyba sekce]")
        put(2, 5, C.bg, colors.lightGray, tostring(errmsg):sub(1, W - 4))
        put(2, 7, C.bg, C.panelDk, "Klikni pro navrat...")
        os.pullEvent("mouse_click")
    end

    slideOut()
end

loadApps()
drawMain(0)

local clockTimer = os.startTimer(30)

while true do
    sync()
    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "timer" and p1 == clockTimer then
        drawHeader(FW_TITLE, nil, 0)
        clockTimer = os.startTimer(30)

    elseif ev == "mouse_scroll" then
        local maxS = math.max(0, (#apps * 3) - (H - 2))
        scroll = math.max(0, math.min(maxS, scroll + (p1 > 0 and 1 or -1)))
        drawMain(0)

    elseif ev == "mouse_click" then
        local mx, my = p2, p3
        for i, app in ipairs(apps) do
            local y = 3 + (i - 1) * 3 - scroll
            if my >= y and my <= y + 1 and mx >= 2 and mx <= W - 2 then
                runSection(app)
                drawMain(0)
                break
            end
        end

    elseif ev == "term_resize" then
        sync()
        drawMain(0)
    end
end