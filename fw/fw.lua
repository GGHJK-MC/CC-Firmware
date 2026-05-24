local i, nOpen, nDelete, nMakeDir, nMove, nCopy = 1, nil, nil, nil, nil, nil
repeat
    local name,    val    = debug.getupvalue(fs.open,    i)
    local nameD,   valD   = debug.getupvalue(fs.delete,  i)
    local nameM,   valM   = debug.getupvalue(fs.makeDir, i)
    local nameMov, valMov = debug.getupvalue(fs.move,    i)
    local nameCop, valCop = debug.getupvalue(fs.copy,    i)
    if name    == "nOpen"    then nOpen    = val    end
    if nameD   == "nDelete"  then nDelete  = valD   end
    if nameM   == "nMakeDir" then nMakeDir = valM   end
    if nameMov == "nMove"    then nMove    = valMov end
    if nameCop == "nCopy"    then nCopy    = valCop end
    i = i + 1
until i > 20
nOpen    = nOpen    or fs.open
nDelete  = nDelete  or fs.delete
nMakeDir = nMakeDir or fs.makeDir
nMove    = nMove    or fs.move
nCopy    = nCopy    or fs.copy

local w, h       = term.getSize()
local inf_path   = "/fw/inf.conf"
local tmp_path   = "/fw/inf.conf.tmp"

local function sha256(msg)
    local band, bxor, bor, bnot = bit32.band, bit32.bxor, bit32.bor, bit32.bnot
    local rshift, lshift, rrotate = bit32.rshift, bit32.lshift, bit32.rrotate
    local function badd(...)
        local s = 0
        for _, v in ipairs({...}) do s = band(s + v, 0xFFFFFFFF) end
        return s
    end
    local K = {
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
    }
    local H = {
        0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
        0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19,
    }
    local msgLen = #msg
    msg = msg .. "\x80"
    while #msg % 64 ~= 56 do msg = msg .. "\x00" end
    local bitLen = msgLen * 8
    for s = 56, 0, -8 do msg = msg .. string.char(band(rshift(bitLen, s), 0xFF)) end
    for blk = 1, #msg, 64 do
        local W = {}
        for j = 1, 16 do
            local o = blk + (j-1)*4
            W[j] = bor(bor(bor(lshift(msg:byte(o),24),lshift(msg:byte(o+1),16)),lshift(msg:byte(o+2),8)),msg:byte(o+3))
        end
        for j = 17, 64 do
            local s0 = bxor(bxor(rrotate(W[j-15],7),rrotate(W[j-15],18)),rshift(W[j-15],3))
            local s1 = bxor(bxor(rrotate(W[j-2],17),rrotate(W[j-2],19)),rshift(W[j-2],10))
            W[j] = badd(W[j-16], s0, W[j-7], s1)
        end
        local a,b,c,d,e,f,g,hh = H[1],H[2],H[3],H[4],H[5],H[6],H[7],H[8]
        for j = 1, 64 do
            local S1    = bxor(bxor(rrotate(e,6),rrotate(e,11)),rrotate(e,25))
            local ch    = bxor(band(e,f),band(bnot(e),g))
            local temp1 = badd(hh,S1,ch,K[j],W[j])
            local S0    = bxor(bxor(rrotate(a,2),rrotate(a,13)),rrotate(a,22))
            local maj   = bxor(bxor(band(a,b),band(a,c)),band(b,c))
            local temp2 = badd(S0,maj)
            hh=g; g=f; f=e; e=badd(d,temp1)
            d=c; c=b; b=a; a=badd(temp1,temp2)
        end
        H[1]=badd(H[1],a); H[2]=badd(H[2],b); H[3]=badd(H[3],c); H[4]=badd(H[4],d)
        H[5]=badd(H[5],e); H[6]=badd(H[6],f); H[7]=badd(H[7],g); H[8]=badd(H[8],hh)
    end
    local result = ""
    for _, v in ipairs(H) do result = result .. string.format("%08x", v) end
    return result
end

local function hashPassword(str)
    if str == "fallback" or str == "" then return str end
    return sha256(str)
end

local defaults = {
    swpass      = "fallback",
    secureboot  = false,
    pwontr      = false,
    version     = "19.11",
    fwrd        = "05/24/2026",
    bootorder   = { { name="GGHJK OS", path="/init_boot" } },
    boottimeout = 2,
    bootbeep    = false,
    theme       = "blue",
    hasbooted   = false,
    rebooted    = false,
}

local config = {}
for k, v in pairs(defaults) do config[k] = v end

local function validateConfig(raw)
    if type(raw) ~= "table" then return end
    for _, key in ipairs({ "swpass", "version", "fwrd", "theme" }) do
        if type(raw[key]) == "string" then config[key] = raw[key] end
    end
    for _, key in ipairs({ "secureboot", "pwontr", "bootbeep", "hasbooted", "rebooted" }) do
        if type(raw[key]) == "boolean" then config[key] = raw[key] end
    end
    if type(raw.boottimeout) == "number" then
        config.boottimeout = math.max(1, math.min(60, math.floor(raw.boottimeout)))
    end
    if type(raw.bootorder) == "table" then
        local safe = {}
        for _, v in ipairs(raw.bootorder) do
            if type(v) == "table"
            and type(v.name) == "string" and #v.name >= 1 and #v.name <= 64
            and type(v.path) == "string" and #v.path >= 1 and #v.path <= 128
            and v.path:sub(1,1) == "/"
            and not v.path:find("%.")
            and #safe < 8 then
                safe[#safe+1] = { name=v.name, path=v.path }
            end
        end
        if #safe > 0 then config.bootorder = safe end
    end
    local validThemes = {
        blue=true, green=true, red=true, purple=true, orange=true,
        cyan=true, yellow=true, pink=true, gray=true, lime=true,
        black=true, white=true,
    }
    if not validThemes[config.theme] then config.theme = "blue" end
end

if fs.exists(inf_path) then
    local f = nOpen(inf_path, "r")
    if f then
        local content = f.readAll(); f.close()
        if #content <= 8192 then
            local ok, decoded = pcall(textutils.unserialize, content)
            if ok and type(decoded) == "table" then validateConfig(decoded) end
        end
    end
end

local _saveOk  = true
local _saveErr = ""

local function readConfigFile(path)
    if not fs.exists(path) then return nil end
    local f = nOpen(path, "r"); if not f then return nil end
    local content = f.readAll(); f.close()
    if not content or content == "" then return nil end
    local ok, decoded = pcall(textutils.unserialize, content)
    if not ok or type(decoded) ~= "table" then return nil end
    return decoded
end

local function saveConfig()
    local ok, data = pcall(textutils.serialize, config)
    if not ok or not data then _saveOk=false; _saveErr="serialize failed"; return false end
    local tf = nOpen(tmp_path, "w"); if not tf then _saveOk=false; _saveErr="tmp open failed"; return false end
    local wok = pcall(function() tf.write(data) end); tf.close()
    if not wok then _saveOk=false; _saveErr="tmp write failed"; return false end
    if not readConfigFile(tmp_path) then _saveOk=false; _saveErr="tmp verify failed"; return false end
    local of = nOpen(inf_path, "w"); if not of then _saveOk=false; _saveErr="main open failed"; return false end
    local mok = pcall(function() of.write(data) end); of.close()
    if not mok then _saveOk=false; _saveErr="main write failed"; return false end
    _saveOk=true; _saveErr=""; return true
end

local themes = {
    blue   = { header=colors.blue,    accent=colors.lightBlue,  sel=colors.cyan    },
    green  = { header=colors.green,   accent=colors.lime,       sel=colors.lime    },
    red    = { header=colors.red,     accent=colors.orange,     sel=colors.orange  },
    purple = { header=colors.purple,  accent=colors.magenta,    sel=colors.pink    },
    orange = { header=colors.orange,  accent=colors.yellow,     sel=colors.yellow  },
    cyan   = { header=colors.cyan,    accent=colors.lightBlue,  sel=colors.white   },
    yellow = { header=colors.yellow,  accent=colors.white,      sel=colors.lime    },
    pink   = { header=colors.pink,    accent=colors.magenta,    sel=colors.magenta },
    gray   = { header=colors.gray,    accent=colors.lightGray,  sel=colors.white   },
    lime   = { header=colors.lime,    accent=colors.green,      sel=colors.white   },
    black  = { header=colors.black,   accent=colors.gray,       sel=colors.lightGray },
    white  = { header=colors.lightGray, accent=colors.white,    sel=colors.cyan    },
}
local themeNames = { "blue","green","red","purple","orange","cyan","yellow","pink","gray","lime","black","white" }
local function theme() return themes[config.theme] or themes.blue end

local function rawSleep(n)
    local timer = os.startTimer(n)
    repeat local e, p = os.pullEventRaw() until e == "timer" and p == timer
end

local MAX_PW_LEN = 128

local function safeRead(replaceChar, maxLen)
    maxLen = maxLen or 256
    local input = ""
    local cx0, cy0 = term.getCursorPos()
    term.setCursorBlink(true)
    while true do
        local event, param = os.pullEventRaw()
        if event == "char" then
            if #input < maxLen then
                input = input .. param
                term.write(replaceChar or param)
            end
        elseif event == "paste" then
            local room = maxLen - #input
            if room > 0 then
                local chunk = param:sub(1, room):gsub("[%c]", "")
                input = input .. chunk
                term.write(replaceChar and string.rep(replaceChar, #chunk) or chunk)
            end
        elseif event == "key" then
            if param == keys.enter then
                term.setCursorBlink(false); return input
            elseif param == keys.backspace and #input > 0 then
                input = input:sub(1, -2)
                local cx, cy = term.getCursorPos()
                if cx > 1 then term.setCursorPos(cx-1, cy); term.write(" "); term.setCursorPos(cx-1, cy) end
            elseif param == keys.delete then
                local _, cy = term.getCursorPos()
                local filled = #input
                term.setCursorPos(cx0, cy0); term.write(string.rep(" ", filled)); term.setCursorPos(cx0, cy0)
                input = ""
            end
        end
    end
end

local function writeLine(x, y, str, fg, bg)
    term.setCursorPos(x, y)
    if fg then term.setTextColor(fg) end
    if bg then term.setBackgroundColor(bg) end
    term.write(str)
end

local function fillLine(y, bg)
    term.setCursorPos(1, y); term.setBackgroundColor(bg or colors.gray); term.clearLine()
end

local function errPopup(title, lines, waitSec)
    local pW = math.min(48, w - 4)
    local pH = #lines + 5
    local pX = math.floor((w - pW) / 2)
    local pY = math.floor((h - pH) / 2)
    term.setBackgroundColor(colors.black)
    for ii = 1, pH+1 do term.setCursorPos(pX+2, pY+ii); term.write(string.rep(" ", pW)) end
    for ii = 0, pH-1 do writeLine(pX, pY+ii, string.rep(" ", pW), colors.black, colors.lightGray) end
    writeLine(pX, pY, string.rep(" ", pW), colors.white, colors.red)
    term.setCursorPos(pX+1, pY); term.setTextColor(colors.yellow); term.write("[X]")
    term.setTextColor(colors.white); term.write(" " .. title)
    writeLine(pX, pY+1, string.rep("-", pW), colors.gray, colors.lightGray)
    for idx, line in ipairs(lines) do
        writeLine(pX+2, pY+1+idx, line, colors.black, colors.lightGray)
    end
    local by = pY + pH - 1
    local okX = pX + math.floor((pW - 6) / 2)
    writeLine(okX, by, "  OK  ", colors.white, colors.red)
    if waitSec then
        rawSleep(waitSec)
    else
        while true do
            local ev, btn, mx, my = os.pullEventRaw()
            if ev == "key" and btn == keys.enter then break end
            if ev == "mouse_click" and my == by then break end
        end
    end
end

local function drawPopupBase(title, lines, ptype)
    local icons  = { info="[i]", warn="[!]", error="[X]", input="[?]" }
    local iconFgs= { info=colors.cyan, warn=colors.yellow, error=colors.red, input=colors.lightBlue }
    local icon   = icons[ptype]  or "[i]"
    local iconFg = iconFgs[ptype] or colors.cyan
    local pW = math.min(46, w - 4)
    local pH = #lines + 5
    local pX = math.floor((w - pW) / 2)
    local pY = math.floor((h - pH) / 2)
    term.setBackgroundColor(colors.black)
    for ii = 1, pH+1 do term.setCursorPos(pX+2, pY+ii); term.write(string.rep(" ", pW)) end
    for ii = 0, pH-1 do writeLine(pX, pY+ii, string.rep(" ", pW), colors.black, colors.lightGray) end
    writeLine(pX, pY, string.rep(" ", pW), colors.white, theme().header)
    term.setCursorPos(pX+1, pY); term.setTextColor(iconFg); term.write(icon)
    term.setTextColor(colors.white); term.write(" " .. title)
    writeLine(pX, pY+1, string.rep("-", pW), colors.gray, colors.lightGray)
    for idx, line in ipairs(lines) do writeLine(pX+2, pY+1+idx, line, colors.black, colors.lightGray) end
    return pX, pY, pH, pW
end

local function showPopup(title, lines, ptype, waitSec)
    drawPopupBase(title, lines, ptype or "info")
    rawSleep(waitSec or math.max(1.2, 0.4 * #lines))
end

local function drawPopup(title, lines, ptype)
    local pX, pY, pH, pW = drawPopupBase(title, lines, ptype or "input")
    local iy = pY + #lines + 3
    writeLine(pX+1, iy, string.rep(" ", pW-2), nil, colors.white)
    term.setCursorPos(pX+1, iy)
    return pX+1, iy
end

local function confirmBox(title, msg, ptype)
    local maxW = 40
    local lines = {}
    local cur = ""
    for word in msg:gmatch("%S+") do
        local try = cur == "" and word or (cur.." "..word)
        if #try <= maxW then cur = try else lines[#lines+1]=cur; cur=word end
    end
    if cur ~= "" then lines[#lines+1] = cur end
    local pW = math.min(46, w - 4)
    local pH = #lines + 7
    local pX = math.floor((w - pW) / 2)
    local pY = math.floor((h - pH) / 2)
    local iconFgs = { warn=colors.yellow, error=colors.red, info=colors.cyan }
    local iconFg  = iconFgs[ptype] or colors.yellow
    for ii=1,pH+1 do writeLine(pX+2,pY+ii,string.rep(" ",pW),nil,colors.black) end
    for ii=0,pH-1 do writeLine(pX,pY+ii,string.rep(" ",pW),nil,colors.lightGray) end
    writeLine(pX, pY, string.rep(" ", pW), colors.white, theme().header)
    term.setCursorPos(pX+1, pY); term.setTextColor(iconFg); term.write("[?]")
    term.setTextColor(colors.white); term.write(" " .. title)
    writeLine(pX, pY+1, string.rep("-", pW), colors.gray, colors.lightGray)
    for idx, line in ipairs(lines) do writeLine(pX+2, pY+1+idx, line, colors.black, colors.lightGray) end
    local by   = pY + #lines + 4
    local yesX = pX + 4
    local noX  = pX + pW - 12
    writeLine(pX+2, by+1, "Y/N or click", colors.gray, colors.lightGray)
    local sel = nil
    local function drawBtns()
        writeLine(yesX, by, sel==true  and "[ Yes ]" or "  Yes  ", colors.white, colors.green)
        writeLine(noX,  by, sel==false and "[ No ] " or "  No   ", colors.white, colors.red)
    end
    drawBtns()
    while true do
        local ev, btn, mx, my = os.pullEventRaw()
        if ev == "mouse_click" and my == by then
            if mx >= yesX and mx <= yesX+6 then return true end
            if mx >= noX  and mx <= noX+6  then return false end
        end
        if ev == "key" then
            if btn == keys.y then return true end
            if btn == keys.n or btn == keys.escape then return false end
            if btn == keys.left or btn == keys.right then sel = (sel ~= true); drawBtns() end
            if btn == keys.enter and sel ~= nil then return sel end
        end
    end
end

local function askPassword(title)
    if config.swpass == "" or config.swpass == "fallback" then return true end
    local _, iy = drawPopup(title, {"Enter password:"}, "input")
    local input = safeRead("*", MAX_PW_LEN)
    if hashPassword(input) == config.swpass then return true end
    local pW = 46
    local pX = math.floor((w - pW) / 2)
    writeLine(pX+1, iy+1, "  Access Denied - Wrong Password  ", colors.white, colors.red)
    rawSleep(1.5)
    os.reboot()
end

local activePage = "System"
local host       = _HOST or ""
local mc_version = host:match("Minecraft%s([%d%.]+)") or "Unknown"
local cc_version = host:match("ComputerCraft%s([%d%.]+)") or "Unknown"
local gosver     = "Not Installed"
if fs.exists("/version/VER.TXT") then
    local f = fs.open("/version/VER.TXT","r")
    if f then gosver = f.readAll():gsub("%s+$",""); f.close() end
end

local function buildTabs()
    local defs = {
        { name="System",   target="System"   },
        { name="Security", target="Security" },
        { name="Boot",     target="Boot"     },
        { name="About",    target="About"    },
        { name="Exit",     target="Exit"     },
    }
    local tabs = {}; local x = 2
    for _, d in ipairs(defs) do
        local label = " " .. d.name .. " "
        tabs[#tabs+1] = { label=label, x=x, width=#label, target=d.target }
        x = x + #label + 1
    end
    return tabs
end
local buttons = buildTabs()

local _lastSaveStatus = ""
local _unsavedChanges = false

local function refreshHeader()
    local t = theme()
    fillLine(1, colors.black)
    for _, btn in ipairs(buttons) do
        local isSel = activePage == btn.target
        term.setCursorPos(btn.x, 1)
        term.setBackgroundColor(isSel and t.header or colors.gray)
        term.setTextColor(isSel and colors.white or colors.lightGray)
        term.write(btn.label)
    end
    fillLine(2, t.header)
    local subtitle = " GGHJK UEFI v" .. (config.version or "?") .. "  |  FW " .. (config.fwrd or "N/A")
    writeLine(2, 2, subtitle, colors.white, t.header)
    if _lastSaveStatus ~= "" then
        local ind = " " .. _lastSaveStatus .. " "
        writeLine(w - #ind, 2, ind, colors.black, _saveOk and colors.green or colors.red)
    elseif _unsavedChanges then
        local ind = " * unsaved "
        writeLine(w - #ind, 2, ind, colors.black, colors.orange)
    end
    fillLine(h, colors.black)
    local footer = "Arrows/Enter  |  Mouse  |  ESC=Exit  |  S=Save  |  (c)2026 GGHJK"
    writeLine(math.floor((w-#footer)/2)+1, h, footer, colors.gray, colors.black)
end

local scrollOffsets = { System=0, Security=0, Boot=0, About=0, Exit=0 }
local CONTENT_TOP = 3

local function contentHeight() return (h - 1) - CONTENT_TOP end

local function clearContent()
    term.setBackgroundColor(colors.gray)
    for y = CONTENT_TOP, h-1 do term.setCursorPos(1, y); term.clearLine() end
end

local function vToS(vy)
    return vy - (scrollOffsets[activePage] or 0) + (CONTENT_TOP - 1)
end

local function sToV(sy)
    return sy + (scrollOffsets[activePage] or 0) - (CONTENT_TOP - 1)
end

local function sectionTitle(vy, title)
    local sy = vToS(vy)
    if sy < CONTENT_TOP or sy > h-1 then return end
    local full = " " .. title .. " "
    writeLine(1, sy, full, colors.white, theme().header)
    local rest = w - #full
    if rest > 0 then writeLine(1+#full, sy, string.rep(" ", rest), colors.white, theme().header) end
end

local function kv(vy, key, val, valColor)
    local sy = vToS(vy)
    if sy < CONTENT_TOP or sy > h-1 then return end
    local valStr = tostring(val)
    local maxValW = w - 27 - 1
    if #valStr > maxValW then valStr = valStr:sub(1, maxValW-2) .. ".." end
    writeLine(3,  sy, key,    colors.lightGray, colors.gray)
    writeLine(27, sy, valStr, valColor or colors.white, colors.gray)
end

local function statusBadge(vy, x, enabled, onText, offText)
    local sy = vToS(vy)
    if sy < CONTENT_TOP or sy > h-1 then return end
    local t = theme()
    local txt = enabled and (onText or " ON ") or (offText or "OFF")
    local bg  = enabled and t.accent or colors.gray
    local fg  = enabled and colors.black or colors.lightGray
    writeLine(x, sy, " " .. txt .. " ", fg, bg)
end

local function drawScrollHints(totalVRows)
    local off = scrollOffsets[activePage] or 0
    local ch  = contentHeight()
    if totalVRows <= ch then return end
    if off > 0 then
        term.setCursorPos(w, CONTENT_TOP); term.setBackgroundColor(colors.gray); term.setTextColor(colors.white); term.write("^")
    end
    if off + ch < totalVRows then
        term.setCursorPos(w, h-1); term.setBackgroundColor(colors.gray); term.setTextColor(colors.white); term.write("v")
    end
end

local function menuItem(vy, label, selected)
    local sy = vToS(vy)
    if sy < CONTENT_TOP or sy > h-1 then return end
    local t   = theme()
    local bg  = selected and t.header or colors.gray
    local fg  = selected and colors.white or colors.yellow
    local row = (selected and "> " or "  ") .. label
    writeLine(3, sy, row, fg, bg)
    local used = 3 + #row
    if used < w then writeLine(used, sy, string.rep(" ", w-used), nil, bg) end
end

function DrawSystem()
    activePage = "System"
    clearContent(); refreshHeader()
    sectionTitle(1, "Software")
    kv(2, "CraftOS Version:",   os.version())
    kv(3, "CC:Tweaked:",        cc_version)
    kv(4, "Minecraft Version:", mc_version)
    kv(5, "GGHJK OS Version:",  gosver)
    sectionTitle(7, "Hardware")
    kv(8,  "Computer ID:",    tostring(os.getComputerID()))
    kv(9,  "Computer Label:", os.getComputerLabel() or "Unnamed")
    kv(10, "Storage Free:",   tostring(math.floor(fs.getFreeSpace("/") / 1024)) .. " KB")
    sectionTitle(12, "Firmware")
    kv(13, "FW Version:",   config.version or "N/A")
    kv(14, "Release Date:", config.fwrd or "N/A")
    kv(15, "Active Theme:", config.theme or "blue", theme().accent)
    kv(16, "Boot Status:",  config.hasbooted and "Initialized" or "First Boot",
           config.hasbooted and colors.lime or colors.yellow)
    sectionTitle(18, "Actions")
    menuItem(19, "Set Computer Label", false)
    menuItem(20, "Refresh System Info", false)
    drawScrollHints(21)
end

local secItems = {
    { label="Toggle PowerOn Password", key="pwontr"     },
    { label="Set Supervisor Password",  key="swpass"    },
    { label="Toggle Boot Images",       key="secureboot"},
    { label="Change Theme",             key="theme"     },
    { label="Reset to Defaults",        key="reset"     },
}
local secSelected = 1

function DrawSecurity()
    activePage = "Security"
    clearContent(); refreshHeader()
    local bX  = w - 8
    local pwNone = (config.swpass == "" or config.swpass == "fallback")
    sectionTitle(1, "Current Settings")
    kv(2, "Supervisor Password:", pwNone and "Not Set" or "Protected")
    statusBadge(2, bX, not pwNone, "SET ", "NONE")
    kv(3, "PowerOn Password:",    config.pwontr and "Enabled" or "Disabled")
    statusBadge(3, bX, config.pwontr, " ON ", "OFF ")
    kv(4, "Boot Images:",         (not config.secureboot) and "Enabled" or "Hidden")
    statusBadge(4, bX, not config.secureboot, "SHOW", "HIDE")
    kv(5, "Active Theme:",        config.theme or "blue", theme().accent)
    sectionTitle(7, "Actions")
    for idx, item in ipairs(secItems) do menuItem(6+idx, item.label, idx == secSelected) end
    local hintSY = vToS(6 + #secItems + 2)
    if hintSY >= CONTENT_TOP and hintSY <= h-1 then
        writeLine(3, hintSY, "Up/Down + Enter, or click", colors.lightGray, colors.gray)
    end
    drawScrollHints(6 + #secItems + 3)
end

local bootSelected = 1

function DrawBoot()
    activePage = "Boot"
    clearContent(); refreshHeader()
    local bootList = config.bootorder or {}
    sectionTitle(1, "Boot Settings")
    kv(2, "Timeout:",   config.boottimeout .. "s")
    kv(3, "Boot Beep:", config.bootbeep and "Enabled" or "Disabled")
    statusBadge(3, w-6, config.bootbeep, " ON ", "OFF")
    sectionTitle(5, "Boot Order")
    for idx, entry in ipairs(bootList) do
        local vy = 5 + idx
        local sy = vToS(vy)
        if sy >= CONTENT_TOP and sy <= h-1 then
            local exists = fs.exists(entry.path)
            local sel    = idx == bootSelected
            local bg     = sel and theme().header or colors.gray
            local fg     = sel and colors.white or colors.yellow
            local ar     = sel and "> " or "  "
            local numTag = "[" .. idx .. "] "
            local nameF  = string.format("%-14s", entry.name)
            local maxPathW = w - 3 - #ar - #numTag - #nameF - 7
            local pathF  = entry.path
            if #pathF > maxPathW then pathF = pathF:sub(1, maxPathW-2) .. ".." end
            writeLine(3, sy, ar .. numTag .. nameF .. " " .. pathF, fg, bg)
            writeLine(w-5, sy, exists and " OK " or " ?? ", colors.black, exists and colors.green or colors.red)
        end
    end
    local ay = 5 + #bootList + 2
    sectionTitle(ay, "Actions")
    local actions = { "Add Entry","Edit Selected","Delete Selected","Move Up","Move Down","Timeout -1s","Timeout +1s","Toggle Beep" }
    for i2, act in ipairs(actions) do menuItem(ay+i2, act, bootSelected == #bootList+i2) end
    drawScrollHints(ay + #actions + 2)
end

function DrawAbout()
    activePage = "About"
    clearContent(); refreshHeader()
    local t = theme()
    sectionTitle(1, "About GGHJK UEFI")
    local logo = {
        "   _____  _____ _    _      _ _  __",
        "  / ____|/ ____| |  | |    | | |/ /",
        " | |  __| |  __| |__| |    | | ' / ",
        " | | |_ | | |_ |  __  |_   | |  <  ",
        " | |__| | |__| | |  | | |__| | . \\ ",
        "  \\_____|\\_____|_|  |_|\\____/|_|\\_\\",
    }
    for i2, line in ipairs(logo) do
        local sy = vToS(1 + i2)
        if sy >= CONTENT_TOP and sy <= h-1 then
            writeLine(math.max(1, math.floor((w-#line)/2)+1), sy, line, t.accent, colors.gray)
        end
    end
    local s = 2 + #logo + 1
    kv(s,   "Product:",      "GGHJK Unified Extensible Firmware Interface")
    kv(s+1, "Version:",      "v" .. (config.version or "?"))
    kv(s+2, "Release Date:", config.fwrd or "N/A")
    kv(s+3, "Copyright:",    "(c) 2026 GGHJK Systems")
    kv(s+4, "License:",      "All rights reserved")
    kv(s+5, "Wiki:",         "wiki.gghjk.net")
    kv(s+6, "Made by:",      "SlientPickaxe")
    drawScrollHints(s + 7)
end

function DrawExit()
    activePage = "Exit"
    clearContent(); refreshHeader()
    local t = theme()
    sectionTitle(1, "Exit Options")
    local opts = {
        { vy=3,  label="Continue Boot",           desc="Resume normal boot sequence",   bg=t.header     },
        { vy=5,  label="Save All",                desc="Write all changes to disk",     bg=colors.green },
        { vy=7,  label="Install latest GGHJK OS", desc="Download and install GGHJK OS", bg=colors.blue  },
        { vy=9,  label="Open Shell",              desc="Drop to CraftOS shell",         bg=colors.gray  },
        { vy=11, label="Reboot System",           desc="Restart the computer",          bg=colors.gray  },
        { vy=13, label="Power Off",               desc="Shut down the computer",        bg=colors.gray  },
    }
    for _, opt in ipairs(opts) do
        local sy = vToS(opt.vy)
        if sy >= CONTENT_TOP and sy <= h-1 then
            local fg = (opt.bg == t.header or opt.bg == colors.green) and colors.white or colors.yellow
            local bg = (opt.label == "Save All" and _unsavedChanges) and colors.lime or opt.bg
            writeLine(3, sy, "  " .. opt.label, fg, bg)
            local dx = 3 + 2 + #opt.label + 2
            writeLine(dx, sy, opt.desc, colors.lightGray, bg)
            if dx + #opt.desc < w then writeLine(dx+#opt.desc, sy, string.rep(" ", w-dx-#opt.desc), nil, bg) end
        end
    end
    local warnSY = vToS(15)
    if warnSY >= CONTENT_TOP and warnSY <= h-1 and _unsavedChanges then
        writeLine(3, warnSY, "  * You have unsaved changes!", colors.orange, colors.gray)
    end
    drawScrollHints(15)
end

local pageDrawers = { System=DrawSystem, Security=DrawSecurity, Boot=DrawBoot, About=DrawAbout, Exit=DrawExit }
local function redraw()
    local fn = pageDrawers[activePage]; if fn then fn() end
end

local function doSecAction(idx)
    local item = secItems[idx]; if not item then return end
    if item.key == "reset" then
        if confirmBox("Reset to Defaults", "Erase ALL settings including password. Are you sure?", "warn") then
            for k, v in pairs(defaults) do config[k] = v end
            config.hasbooted = true; config.rebooted = false
            local ok = saveConfig()
            _lastSaveStatus = ok and "RESET OK" or "RESET FAIL"
        end
        DrawSecurity(); return
    end
    if item.key == "pwontr" then
        if not config.pwontr and (config.swpass == "" or config.swpass == "fallback") then
            showPopup("Cannot Enable", {"Set a Supervisor Password first.", "PowerOn requires one."}, "warn")
            DrawSecurity(); return
        end
        config.pwontr = not config.pwontr
        _unsavedChanges = true
        _lastSaveStatus = saveConfig() and "Saved" or "Save Error"
        DrawSecurity()
    elseif item.key == "swpass" then
        local _, iy = drawPopup("Set Password", {"New password (blank = remove):","Min 4 chars recommended."}, "input")
        local input = safeRead("*", MAX_PW_LEN)
        if input ~= "" and #input < 4 then
            showPopup("Too Short", {"Password must be at least 4 characters.", "Password NOT changed."}, "warn")
            DrawSecurity(); return
        end
        if input == "" then
            if config.pwontr then
                showPopup("Note", {"PowerOn Password disabled because","Supervisor Password was removed."}, "info")
                config.pwontr = false
            end
            config.swpass = "fallback"
        else
            config.swpass = hashPassword(input)
        end
        _unsavedChanges = true
        _lastSaveStatus = saveConfig() and "Saved" or "Save Error"
        DrawSecurity()
    elseif item.key == "secureboot" then
        config.secureboot = not config.secureboot
        _unsavedChanges = true
        _lastSaveStatus = saveConfig() and "Saved" or "Save Error"
        DrawSecurity()
    elseif item.key == "theme" then
        local cur = 1
        for i2, n in ipairs(themeNames) do if n == config.theme then cur = i2 end end
        cur = (cur % #themeNames) + 1
        config.theme = themeNames[cur]
        _unsavedChanges = true
        _lastSaveStatus = saveConfig() and "Saved" or "Save Error"
        DrawSecurity()
    end
end

local function inputPopup(promptTitle, promptMsg, default)
    local lines = {promptMsg}
    if default and default ~= "" then lines[#lines+1] = "Current: " .. default end
    local _, _ = drawPopup(promptTitle, lines, "input")
    return safeRead(nil, 128)
end

local function doBootAction(vy)
    local bootList = config.bootorder or {}
    if vy >= 6 and vy <= 5 + #bootList then
        bootSelected = vy - 5; DrawBoot(); return
    end
    local ay = 5 + #bootList + 2
    local function saved()
        local ok = saveConfig()
        _lastSaveStatus = ok and "Saved" or "Save Error"
        _unsavedChanges = true
        return ok
    end
    if vy == ay+1 then
        if #bootList >= 8 then showPopup("Cannot Add", {"Maximum 8 boot entries reached."}, "warn"); DrawBoot(); return end
        local nameIn = inputPopup("Add Boot Entry", "Name (e.g. GGHJK OS):", "")
        if nameIn == "" then DrawBoot(); return end
        local pathIn = inputPopup("Boot Path", "Absolute path (e.g. /init_boot):", "")
        if pathIn == "" then DrawBoot(); return end
        if pathIn:sub(1,1) ~= "/" then showPopup("Invalid Path", {"Path must start with /."}, "warn"); DrawBoot(); return end
        if pathIn:find("%.%.") then showPopup("Invalid Path", {"Path cannot contain .."}, "error"); DrawBoot(); return end
        table.insert(bootList, { name=nameIn, path=pathIn })
        config.bootorder = bootList; bootSelected = #bootList; saved(); DrawBoot()
    elseif vy == ay+2 then
        if #bootList == 0 then DrawBoot(); return end
        local e = bootList[bootSelected]
        local newName = inputPopup("Edit Name", "Name:", e.name)
        if newName == "" then newName = e.name end
        local newPath = inputPopup("Edit Path", "Path:", e.path)
        if newPath == "" then newPath = e.path end
        if newPath:sub(1,1) ~= "/" then showPopup("Invalid Path", {"Path must start with /."}, "warn"); DrawBoot(); return end
        if newPath:find("%.%.") then showPopup("Invalid Path", {"Path cannot contain .."}, "error"); DrawBoot(); return end
        bootList[bootSelected] = { name=newName, path=newPath }
        config.bootorder = bootList; saved(); DrawBoot()
    elseif vy == ay+3 then
        if #bootList == 0 then DrawBoot(); return end
        if #bootList == 1 then showPopup("Cannot Delete", {"At least one boot entry is required."}, "warn"); DrawBoot(); return end
        if confirmBox("Delete Entry", "Delete '" .. bootList[bootSelected].name .. "'?", "warn") then
            table.remove(bootList, bootSelected)
            config.bootorder = bootList
            if bootSelected > #bootList then bootSelected = #bootList end
            saved()
        end; DrawBoot()
    elseif vy == ay+4 then
        if bootSelected > 1 then
            bootList[bootSelected], bootList[bootSelected-1] = bootList[bootSelected-1], bootList[bootSelected]
            config.bootorder = bootList; bootSelected = bootSelected-1; saved()
        end; DrawBoot()
    elseif vy == ay+5 then
        if bootSelected < #bootList then
            bootList[bootSelected], bootList[bootSelected+1] = bootList[bootSelected+1], bootList[bootSelected]
            config.bootorder = bootList; bootSelected = bootSelected+1; saved()
        end; DrawBoot()
    elseif vy == ay+6 then
        config.boottimeout = math.max(1, config.boottimeout-1); saved(); DrawBoot()
    elseif vy == ay+7 then
        config.boottimeout = math.min(60, config.boottimeout+1); saved(); DrawBoot()
    elseif vy == ay+8 then
        config.bootbeep = not config.bootbeep; saved(); DrawBoot()
    end
end

local function doSaveAll()
    local ok = saveConfig()
    _lastSaveStatus = ok and "Saved!" or "Save Error!"
    if ok then
        _unsavedChanges = false
        showPopup("Saved", {"All settings saved successfully."}, "info", 0.8)
    else
        errPopup("Save Error", {"Write failed: " .. _saveErr, "Path: " .. inf_path})
    end
    redraw()
end

local function doSystemAction(vy)
    if vy == 19 then
        local _, _ = drawPopup("Set Label", {"Enter new computer label:", "(blank = clear label)"}, "input")
        local input = safeRead(nil, 32)
        if input == "" then
            os.setComputerLabel(nil)
            showPopup("Label Cleared", {"Computer label removed."}, "info", 0.8)
        else
            os.setComputerLabel(input)
            showPopup("Label Set", {"Label set to: " .. input}, "info", 0.8)
        end
        DrawSystem()
    elseif vy == 20 then
        if fs.exists("/version/VER.TXT") then
            local f = fs.open("/version/VER.TXT","r")
            if f then gosver = f.readAll():gsub("%s+$",""); f.close() end
        end
        DrawSystem()
    end
end

local function openUEFI()
    if not askPassword("UEFI Setup") then return end
    term.setBackgroundColor(colors.gray); term.clear()
    activePage = "System"; _lastSaveStatus = ""
    redraw()
    while true do
        local event, btn, x, y = os.pullEventRaw()
        if event == "mouse_click" then
            if y == 1 then
                for _, b in ipairs(buttons) do
                    if x >= b.x and x < b.x + b.width then activePage = b.target; redraw(); break end
                end
            elseif activePage == "Exit" then
                local vy = sToV(y)
                if     vy == 3  then return
                elseif vy == 5  then doSaveAll()
                elseif vy == 7  then
                    term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
                    shell.run("pastebin run RyixbgfH"); redraw()
                elseif vy == 9  then
                    term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
                    shell.run("shell"); redraw()
                elseif vy == 11 then
                    if confirmBox("Reboot", "Reboot the computer now?", "warn") then
                        config.rebooted = true; saveConfig(); os.reboot()
                    else DrawExit() end
                elseif vy == 13 then
                    if confirmBox("Power Off", "Shut down the computer?", "warn") then
                        os.shutdown()
                    else DrawExit() end
                end
            elseif activePage == "Security" then
                local vy = sToV(y)
                for idx, item in ipairs(secItems) do
                    if vy == 6+idx then secSelected = idx; doSecAction(idx); break end
                end
            elseif activePage == "Boot" then
                doBootAction(sToV(y))
            elseif activePage == "System" then
                doSystemAction(sToV(y))
            end
        elseif event == "mouse_scroll" then
            scrollOffsets[activePage] = math.max(0, (scrollOffsets[activePage] or 0) + btn * 2)
            redraw()
        elseif event == "key" then
            if activePage == "Security" then
                if     btn == keys.up    then secSelected = math.max(1, secSelected-1); DrawSecurity()
                elseif btn == keys.down  then secSelected = math.min(#secItems, secSelected+1); DrawSecurity()
                elseif btn == keys.enter then doSecAction(secSelected)
                elseif btn == keys.s     then doSaveAll()
                elseif btn == keys.escape then return end
            elseif activePage == "Boot" then
                local bootList = config.bootorder or {}
                local ay = 5 + #bootList + 2
                if     btn == keys.up   then bootSelected = math.max(1, bootSelected-1); DrawBoot()
                elseif btn == keys.down then bootSelected = math.min(#bootList+8, bootSelected+1); DrawBoot()
                elseif btn == keys.enter then
                    if bootSelected <= #bootList then doBootAction(5+bootSelected)
                    else doBootAction(ay + (bootSelected-#bootList)) end
                elseif btn == keys.s     then doSaveAll()
                elseif btn == keys.escape then return end
            elseif activePage == "Exit" then
                if btn == keys.escape or btn == keys.q then return end
            else
                if     btn == keys.up       then scrollOffsets[activePage] = math.max(0, (scrollOffsets[activePage] or 0)-1); redraw()
                elseif btn == keys.down     then scrollOffsets[activePage] = (scrollOffsets[activePage] or 0)+1; redraw()
                elseif btn == keys.pageUp   then scrollOffsets[activePage] = math.max(0, (scrollOffsets[activePage] or 0)-contentHeight()); redraw()
                elseif btn == keys.pageDown then scrollOffsets[activePage] = (scrollOffsets[activePage] or 0)+contentHeight(); redraw()
                elseif btn == keys.s        then doSaveAll()
                elseif btn == keys.escape   then return end
            end
        end
    end
end

local splashBottomY = math.floor(h / 2)

local function drawSplash(path)
    local f = nOpen(path, "r"); if not f then term.clear(); return end
    local raw = f.readAll(); f.close()
    local ok, img = pcall(paintutils.parseImage, raw)
    if not ok or type(img) ~= "table" or #img == 0 then term.clear(); return end
    term.setBackgroundColor(colors.black); term.clear()
    local imgH = #img
    local imgW = (type(img[1]) == "table") and #img[1] or 0
    local startY = math.max(1, math.floor((h-imgH)/2) - 2)
    paintutils.drawImage(img, math.floor((w-imgW)/2)+1, startY)
    splashBottomY = startY + imgH
end

local function playBootBeep()
    local speaker = peripheral.find("speaker")
    if not speaker then return end
    local ok, err = pcall(function()
        speaker.playNote("harp", 1.0, 12)
        rawSleep(0.1)
        speaker.playNote("harp", 1.0, 16)
        rawSleep(0.1)
        speaker.playNote("harp", 1.0, 19)
    end)
end

local function loading(secs)
    local DOTS   = 9
    local DOT_GAP = 1
    local totalW = DOTS + (DOTS-1)*DOT_GAP
    local startX = math.floor((w-totalW)/2)+1
    local dotY   = splashBottomY + 2
    local barY   = dotY + 2
    local t      = theme()
    local label  = "Press [B] to enter UEFI Setup"
    writeLine(math.floor((w-#label)/2)+1, dotY-1, label, colors.lightGray, colors.black)
    local totalSteps = math.floor(secs / 0.1)
    for step = 0, totalSteps do
        local progress = math.min(1, step / totalSteps)
        local filled   = math.min(DOTS, math.floor(progress*DOTS)+1)
        for d = 1, DOTS do
            local dx = startX + (d-1)*(DOT_GAP+1)
            term.setCursorPos(dx, dotY)
            term.setBackgroundColor(d <= filled and t.accent or colors.gray)
            term.write(" ")
        end
        local barW    = math.min(w-4, 46)
        local barX    = math.floor((w-barW)/2)+1
        local filledW = math.floor(progress*barW)
        writeLine(barX, barY, string.rep(" ", filledW), nil, t.header)
        term.setBackgroundColor(colors.gray); term.write(string.rep(" ", barW-filledW))
        local remaining = math.max(0, math.ceil(secs - step*0.1))
        local cnt = "Booting in " .. remaining .. "s..."
        writeLine(math.floor((w-#cnt)/2)+1, barY+1, cnt, colors.lightGray, colors.black)
        if step < totalSteps then rawSleep(0.1) end
    end
end

local showSplash  = true
local setupDirect = false

if config.hasbooted then
    if config.rebooted then
        config.rebooted = false; saveConfig()
        showSplash = true; setupDirect = false
    else
        showSplash = false; setupDirect = true
    end
end

if setupDirect then
    openUEFI()
else
    term.setBackgroundColor(colors.black); term.clear()
    if not config.secureboot then
        drawSplash("/fw/assets/logo.nfp")
    else
        splashBottomY = math.floor(h/2)
    end
    local setupRequested = false
    parallel.waitForAny(
        function() loading(config.boottimeout or 2) end,
        function()
            local timer = os.startTimer(config.boottimeout or 2)
            while true do
                local ev, p1 = os.pullEventRaw()
                if ev == "key" and p1 == keys.b then setupRequested = true; return end
                if ev == "timer" and p1 == timer then return end
            end
        end
    )
    if setupRequested then openUEFI() end
end

if not config.hasbooted then
    config.hasbooted = true; saveConfig()
end

if config.pwontr then
    if not askPassword("System Boot") then os.reboot() end
end

if config.bootbeep then
    playBootBeep()
end

local _realOpen    = fs.open
local _realDelete  = fs.delete
local _realMakeDir = fs.makeDir
local _realMove    = fs.move
local _realCopy    = fs.copy

local function isFW(p)
    if not p then return false end
    local ps = tostring(p)
    if ps:find("%.%.") then return true end
    local norm = fs.combine("/", ps):lower()
    return norm == "fw" or norm:sub(1,3) == "fw/"
end

fs.open    = function(p, m)    if isFW(p) and (m=="w" or m=="a") then return nil,"Access Denied" end; return _realOpen(p, m) end
fs.delete  = function(p)       if isFW(p) then error("Access Denied",2) end; return _realDelete(p) end
fs.makeDir = function(p)       if isFW(p) then error("Access Denied",2) end; return _realMakeDir(p) end
fs.move    = function(f, t2)   if isFW(f) or isFW(t2) then error("Access Denied",2) end; return _realMove(f, t2) end
fs.copy    = function(f, t2)   if isFW(t2) then error("Access Denied",2) end; return _realCopy(f, t2) end

nDelete = nil; nMakeDir = nil

term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)

local booted = false
for _, entry in ipairs(config.bootorder or {}) do
    local path = entry.path
    if type(path) == "string" and path:sub(1,1) == "/" and not path:find("%.") and #path <= 128 and fs.exists(path) then
        local f = fs.open(path, "r")
        if f then
            local src = f.readAll(); f.close()
            local fn, err = load(src, path, "t", _ENV)
            if fn then
                local ok2, runErr = pcall(fn)
                if ok2 then
                    booted = true; break
                else
                    errPopup("Boot Error", {
                        "Runtime error in:", path, "", tostring(runErr):sub(1,40)
                    })
                end
            else
                errPopup("Boot Error", {
                    "Syntax error in:", path, "", tostring(err):sub(1,40)
                })
            end
        end
    end
end

if not booted then
    local f2 = _realOpen("/fw/warn/noos.lua","r")
    if f2 then
        local src = f2.readAll(); f2.close()
        local fn, err = load(src, "/fw/warn/noos.lua", "t", _ENV)
        if fn then
            local ok2, runErr = pcall(fn)
            if not ok2 then
                term.setTextColor(colors.red)
                print("noos.lua error: " .. tostring(runErr))
            end
        else
            term.setTextColor(colors.red)
            print("Boot error in noos.lua: " .. tostring(err))
        end
    else
        term.setTextColor(colors.red)
        print("FATAL: No OS found. Add a boot entry in UEFI Setup.")
    end
end
