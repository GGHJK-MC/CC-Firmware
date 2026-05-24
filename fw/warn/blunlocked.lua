local i, nOpen = 1, nil
repeat
    local name, val = debug.getupvalue(fs.open, i)
    if name == "nOpen" then nOpen = val end
    i = i + 1
until i > 20
nOpen = nOpen or fs.open

local w, h = term.getSize()

term.setBackgroundColor(colors.black)
term.clear()

local f = nOpen("/fw/assets/warn.nfp", "r")
if f then
    local ok, img = pcall(paintutils.parseImage, f.readAll()); f.close()
    if ok and img and #img > 0 then
        local imgW = (type(img[1]) == "table") and #img[1] or 0
        paintutils.drawImage(img, math.max(1, math.floor((w - imgW) / 2) + 1), 2)
    end
end

term.setBackgroundColor(colors.orange)
term.setTextColor(colors.black)
term.setCursorPos(1, 1)
term.write(string.rep(" ", w))
term.setCursorPos(1, 1)
term.write("  [!] GGHJK UEFI  |  Security Warning")

term.setBackgroundColor(colors.black)

local function wc(y, text, fg)
    term.setTextColor(fg or colors.white)
    term.setCursorPos(math.floor((w - #text) / 2) + 1, y)
    term.write(text)
end

wc(8,  "BOOTLOADER UNLOCKED", colors.orange)
wc(9,  "Device integrity cannot be verified.", colors.white)
wc(11, "Boot image checks are disabled.", colors.lightGray)
wc(12, "This device may have been modified.", colors.lightGray)
wc(14, "More info:  wiki.gghjk.net/cs/gvb/877", colors.red)
wc(h,  "GGHJK UEFI | Unlock Warning", colors.gray)
local WAIT = 5
for remaining = WAIT, 1, -1 do
    wc(h-1, "Continuing boot in " .. remaining .. "s...", colors.yellow)
    local t = os.startTimer(1)
    repeat local ev, p1 = os.pullEventRaw() until ev == "timer" and p1 == t
end
term.setCursorPos(1, h-1)
term.setBackgroundColor(colors.black)
term.write(string.rep(" ", w))
