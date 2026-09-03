label = "Sprava hesel"
color = "colors.orange"
desc = "FW heslo a startup heslo"

local popup = require("fw.api.popup")
local w, h = term.getSize()

local function getRaw()
    local i, f = 1, nil
    repeat
        local name, val = debug.getupvalue(fs.open, i)
        if name == "nOpen" then f = val end
        i = i + 1
    until i > 30
    return f or fs.open
end
local nOpen = getRaw()

local sha = require("fw.api.sha256")

local function readHash(path)
    local f = nOpen(path, "r")
    if f then
        local c = f.readAll(); f.close()
        return (c and c:gsub("%s+","") ~= "") and c:gsub("%s+","") or nil
    end
end

local function writeHash(path, h)
    local f = nOpen(path, "w")
    if f then f.write(h or ""); f.close(); return true end
    return false
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

local function drawPanel()
    fill(1, 3, w, h, colors.gray)

    local fwHash    = readHash("/fw/seccfg/passhash")
    local startHash = readHash("/fw/seccfg/starthash")

    fill(3, 4, w - 2, 7, colors.lightGray)
    term.setBackgroundColor(colors.orange)
    term.setTextColor(colors.black)
    term.setCursorPos(3, 4)
    term.write("  Heslo firmwaru (FW Lock)  ")
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.setCursorPos(4, 5)
    term.write("Stav: ")
    term.setTextColor(fwHash and colors.red or colors.lime)
    term.write(fwHash and "NASTAVENO" or "Nenastaveno")
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.setCursorPos(4, 6)
    term.write(fwHash and " Zmenit heslo " or " Nastavit heslo ")
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    if fwHash then
        term.setCursorPos(21, 6)
        term.setBackgroundColor(colors.red)
        term.write(" Odebrat heslo ")
    end

    fill(3, 9, w - 2, 12, colors.lightGray)
    term.setBackgroundColor(colors.orange)
    term.setTextColor(colors.black)
    term.setCursorPos(3, 9)
    term.write("  Startup heslo (Boot Lock) ")
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.setCursorPos(4, 10)
    term.write("Stav: ")
    term.setTextColor(startHash and colors.red or colors.lime)
    term.write(startHash and "NASTAVENO" or "Nenastaveno")
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.setCursorPos(4, 11)
    term.write(startHash and " Zmenit heslo " or " Nastavit heslo ")
    if startHash then
        term.setCursorPos(21, 11)
        term.setBackgroundColor(colors.red)
        term.write(" Odebrat heslo ")
    end
end

local function changePassword(label, hashPath)
    local current = readHash(hashPath)
    if current then
        local pw = popup.password("Overeni - " .. label, "Zadejte soucasne heslo:")
        if not pw then return end
        if not sha.verify(pw, current) then
            popup.error("Chyba", "Spatne heslo. Zmena zrusena.")
            return
        end
    end

    local pw1 = popup.password("Nove heslo - " .. label, "Zadejte nove heslo:")
    if not pw1 or pw1 == "" then
        popup.warn("Zruseno", "Heslo nebylo zmeneno.")
        return
    end
    local pw2 = popup.password("Potvrzeni hesla", "Zadejte heslo znovu:")
    if pw1 ~= pw2 then
        popup.error("Chyba", "Hesla se neshoduji!")
        return
    end

    writeHash(hashPath, sha.hash(pw1))
    popup.toast("Heslo ulozeno!", 2)
end

local function removePassword(label, hashPath)
    local current = readHash(hashPath)
    if not current then return end
    local pw = popup.password("Odebrani - " .. label, "Potvrdte heslem:")
    if not pw then return end
    if not sha.verify(pw, current) then
        popup.error("Chyba", "Spatne heslo.")
        return
    end
    if popup.confirm("Odebrat heslo", "Opravdu odebrat " .. label .. "?") then
        writeHash(hashPath, "")
        popup.toast("Heslo odebrano.", 2)
    end
end

drawPanel()

while true do
    local ev, btn, mx, my = os.pullEvent("mouse_click")
    if my == 1 and mx >= 2 and mx <= 7 then break end

    if my == 6 and mx >= 4 and mx <= 19 then
        changePassword("FW Lock", "/fw/seccfg/passhash")
        drawPanel()
    elseif my == 6 and mx >= 21 and mx <= 36 then
        removePassword("FW Lock", "/fw/seccfg/passhash")
        drawPanel()

    elseif my == 11 and mx >= 4 and mx <= 19 then
        changePassword("Boot Lock", "/fw/seccfg/starthash")
        drawPanel()
    elseif my == 11 and mx >= 21 and mx <= 36 then
        removePassword("Boot Lock", "/fw/seccfg/starthash")
        drawPanel()
    end
end
