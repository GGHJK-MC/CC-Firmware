local i, nOpen = 1, nil
repeat
    local name, val = debug.getupvalue(fs.open, i)
    if name == "nOpen" then nOpen = val end
    i = i + 1
until i > 20
nOpen = nOpen or fs.open

local w, h = term.getSize()
term.clear()

local f = nOpen("/fw/assets/warn.nfp", "r")
if f then
    local img = paintutils.parseImage(f.readAll())
    f.close()
    paintutils.drawImage(img, 2, 2)
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.setCursorPos(1,8)
term.write("This computer bootloader is unlocked and")
term.setCursorPos(1,9)
term.write("its integrity cannot be verifed")
term.setCursorPos(1,11)
term.write("For more help, visit our help page:")
term.setCursorPos(1,12)
term.setTextColor(colors.red)
term.write("https://wiki.gghjk.net/cs/gvb/877")
term.setCursorPos(1,h)
term.setTextColor(colors.white)
term.write("Device will boot in 5 Seconds.")

local t = os.startTimer(5)
while true do
    local ev, p1 = os.pullEventRaw()
    if ev == "timer" and p1 == t then
        break
    end
end
