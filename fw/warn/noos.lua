local i, nOpen = 1, nil
repeat
    local name, val = debug.getupvalue(fs.open, i)
    if name == "nOpen" then nOpen = val end
    i = i + 1
until i > 20
nOpen = nOpen or fs.open

term.clear()
local f = nOpen("/fw/assets/err.nfp", "r")
if f then
    local img = paintutils.parseImage(f.readAll())
    f.close()
    paintutils.drawImage(img, 2, 2)
end
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.setCursorPos(1, 8)
term.write("No valid operating system could be found.")
term.setCursorPos(1, 10)
term.write("Please install any operating system or make valid /boot.img .")
term.setCursorPos(1,12)
term.write("For more help, visit our help page:")
term.setTextColor(colors.red)
term.setCursorPos(1,13)
term.write("https://wiki.gghjk.net/cs/gvb/404")

while true do
    os.pullEventRaw()
end
