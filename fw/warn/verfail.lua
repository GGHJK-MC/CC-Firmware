local i, nOpen = 1, nil
repeat
    local name, val = debug.getupvalue(fs.open, i)
    if name == "nOpen" then nOpen = val end
    i = i + 1
until i > 20
nOpen = nOpen or fs.open

local function loadImage(path)
    local f = nOpen(path, "r")
    if not f then return nil end
    local data = f.readAll()
    f.close()
    return paintutils.parseImage(data)
end

term.clear()
local img = loadImage("/fw/assets/err.nfp")
if img then paintutils.drawImage(img, 2, 2) end
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.setCursorPos(1,8)
term.write("Device is corrupt and cannot be trusted")
term.setCursorPos(1,9)
term.write("and will not boot.")
term.setCursorPos(1,11)
term.write("For more help, visit our help page:")
term.setTextColor(colors.red)
term.setCursorPos(1,12)
term.write("https://wiki.gghjk.net/cs/gvb/5004")

while true do
    os.pullEventRaw()
end
