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

local f = nOpen("/fw/assets/err.nfp", "r")
if f then
    local ok, img = pcall(paintutils.parseImage, f.readAll()); f.close()
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
term.write("  [X] GGHJK UEFI  |  Verification Failure")

term.setBackgroundColor(colors.black)

local function wc(y, text, fg)
    term.setTextColor(fg or colors.white)
    term.setCursorPos(math.floor((w - #text) / 2) + 1, y)
    term.write(text)
end

wc(8,  "DEVICE INTEGRITY CHECK FAILED", colors.red)
wc(9,  "This device is corrupt and cannot be trusted.", colors.white)
wc(10, "Boot halted to protect your data.", colors.lightGray)
wc(12, "Possible causes:", colors.lightGray)
wc(13, "Tampered firmware  |  Hardware fault  |  Corruption", colors.orange)
wc(15, "Recovery:  wiki.gghjk.net/cs/gvb/5004", colors.red)
wc(h,  "GGHJK UEFI | Boot Halt - Integrity Error", colors.gray)
local t = os.startTimer(1)
local blink = true
while true do
    local ev, p1 = os.pullEventRaw()
    if ev == "timer" and p1 == t then
        blink = not blink
        wc(17, blink and "-- SYSTEM HALTED --" or "                   ", blink and colors.red or colors.black)
        t = os.startTimer(1)
    end
end
