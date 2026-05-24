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
term.write("  [X] GGHJK UEFI  |  Boot Error")

term.setBackgroundColor(colors.black)

local function wc(y, text, fg)
    term.setTextColor(fg or colors.white)
    term.setCursorPos(math.floor((w - #text) / 2) + 1, y)
    term.write(text)
end

wc(8,  "No valid operating system was found.", colors.white)
wc(9,  "The computer cannot start.", colors.lightGray)
wc(11, "Configure boot order in UEFI Setup")
wc(14, "Press [B] at startup to enter UEFI Setup.", colors.yellow)
wc(16, "Help:  wiki.gghjk.net/cs/gvb/404", colors.red)
wc(h,  "GGHJK UEFI | Boot Halted", colors.gray)
local t = os.startTimer(0.8)
local blink = true
while true do
    local ev, p1 = os.pullEventRaw()
    if ev == "timer" and p1 == t then
        blink = not blink
        wc(14, "Press [B] at startup to enter UEFI Setup.", blink and colors.yellow or colors.gray)
        t = os.startTimer(0.8)
    end
    if ev == "key" and p1 == keys.b then os.reboot() end
end
