os.pullEvent = os.pullEventRaw

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

local calculateHash = sha256

local function parseVersion(vStr)
    local parts = {}
    for n in tostring(vStr):gsub("%s+", ""):gmatch("%d+") do
        table.insert(parts, tonumber(n))
    end
    return parts
end

local function isNewerVersion(remote, local_)
    local r = parseVersion(remote)
    local l = parseVersion(local_)
    local len = math.max(#r, #l)
    for i = 1, len do
        local rv = r[i] or 0
        local lv = l[i] or 0
        if rv > lv then return true end
        if rv < lv then return false end
    end
    return false
end

local socketPath  = "/disk/sbrom.socket"
local payloadPath = "/disk/payload.sbrom"
local certHash    = "46d19d6a9eeaf41ea7857b38df44d5fabd513edf3abda12a64db7b151c9fdbdd"

if fs.exists(socketPath) then
    local f = fs.open(socketPath, "r")
    if f then
        local content = f.readAll() or ""
        f.close()
        if calculateHash(content) == certHash and fs.exists(payloadPath) then
            shell.run(payloadPath)
        end
    end
end

local undevurl = http.get("https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/refs/heads/master/dev.json")
if not undevurl then return end
local unlockd = textutils.unserializeJSON(undevurl.readAll())
undevurl.close()
local id         = os.getComputerID()
local unstate    = unlockd["pc" .. id] or "no"
local nativePull = os.pullEvent

local MANIFEST_URL   = "https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/master/installmn.json"
local VERSION_URL    = "https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/master/ver.txt"
local FWRD_URL       = "https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/master/fwrd.txt"
local HASH_URL       = "https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/master/gvbchechsum.json"
local INF_PATH       = "/fw/inf.conf"
local PRELOADER      = "/fw/preloader.autorun"
local VERFAIL_SCRIPT = "/fw/warn/verfail.lua"

local function loadConfig()
    if not fs.exists(INF_PATH) then return { version = "0" } end
    local f = fs.open(INF_PATH, "r")
    if not f then return { version = "0" } end
    local data = textutils.unserialize(f.readAll())
    f.close()
    return type(data) == "table" and data or { version = "0" }
end

if not fs.exists(INF_PATH) then
    if not fs.exists("/fw") then fs.makeDir("/fw") end
    local r = http.get("https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/master/fw/inf.conf")
    if r then
        local f = fs.open(INF_PATH, "w")
        if f then f.write(r.readAll()); f.close() end
        r.close()
    end
end

local config       = loadConfig()
local localVersion = tostring(config.version or "0")

local vRes          = http.get(VERSION_URL)
local remoteVersion = vRes and vRes.readAll():gsub("%s+", "") or nil
if vRes then vRes.close() end

local isUpdate      = false
local needsDownload = false

if remoteVersion and isNewerVersion(remoteVersion, localVersion) then
    isUpdate      = true
    needsDownload = true
    if fs.exists("/fw") then
        for _, file in ipairs(fs.list("/fw")) do
            if file ~= "inf.conf" then
                fs.delete(fs.combine("/fw", file))
            end
        end
    end
elseif remoteVersion then
    needsDownload = false
else
    os.pullEvent = nativePull
    if fs.exists(PRELOADER) then
        shell.run(PRELOADER)
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.red)
        term.clear()
        term.setCursorPos(1,1)
        print("[GGHJK] No network & /fw missing. Cannot boot.")
        print("Restore /fw or connect to internet.")
        while true do os.pullEventRaw() end
    end
    return
end

local mRes = http.get(MANIFEST_URL)
if not mRes then
    os.pullEvent = nativePull
    if fs.exists(PRELOADER) then shell.run(PRELOADER) else os.reboot() end
    return
end
local manifest = textutils.unserializeJSON(mRes.readAll())
mRes.close()
if type(manifest) ~= "table" then
    os.pullEvent = nativePull
    if fs.exists(PRELOADER) then shell.run(PRELOADER) else os.reboot() end
    return
end

local toDownload  = {}
local integrityOk = true

for _, mFile in ipairs(manifest) do
    local localPath = fs.combine(mFile.dir, mFile.name)
    local needThis  = false
    if not fs.exists(localPath) then
        needThis      = true
        needsDownload = true
    else
        local f = fs.open(localPath, "r")
        if f then
            local content = f.readAll() or ""
            f.close()
            if calculateHash(content) ~= mFile.hash then
                needThis = true
                if not isUpdate then integrityOk = false end
                needsDownload = true
            end
        else
            needThis      = true
            needsDownload = true
        end
    end
    if needThis then table.insert(toDownload, mFile) end
end

if not needsDownload then
    os.pullEvent = nativePull
    shell.run(PRELOADER)
    return
end

-- ── Loading screen ────────────────────────────────────────────
local w, h = term.getSize()

-- Embedded NFP data — parsed at runtime, no file dependency
local IMG1_LINES = {
    "  0  0  0  0 f",
    " 000000000000",
    "00          00",
    " 0          0",
    "00  000000  00",
    " 0  0eeee0  0",
    "00  000000  00",
    " 0          0",
    "00          00",
    " 000000000000",
    "f 0  0  0  0",
}
local IMG2_LINES = {
    "     1111   f",
    "     1111",
    "     1111",
    "     1111",
    "     1111",
    "     1111",
    "  1111111111",
    "  1111111111",
    "   11111111",
    "    111111",
    "f    1111",
}

-- NFP parser: hex digit sets color, space emits pixel, digit itself is not a pixel
local function parseNfp(lines)
    local img = {}
    for _, line in ipairs(lines) do
        local row     = {}
        local curColor = nil
        for i = 1, #line do
            local ch  = line:sub(i, i)
            local hex = tonumber(ch, 16)
            if hex then
                curColor = 2 ^ hex
            elseif ch == " " then
                row[#row + 1] = curColor
            end
        end
        img[#img + 1] = row
    end
    return img
end

local images = {
    parseNfp(IMG1_LINES),
    parseNfp(IMG2_LINES),
}

local labelText = "Instalace aktualizace systemu"
local barWidth  = 20
local barX      = math.floor((w - barWidth) / 2) + 1
local barY      = h - 1

local imgW = 0
for _, row in ipairs(images[1]) do
    if #row > imgW then imgW = #row end
end
local imgH  = #images[1]
local imgX  = math.floor((w - imgW) / 2) + 1
local imgY  = math.floor((h - imgH - 4) / 2) + 1
local textX = math.floor((w - #labelText) / 2) + 1
local textY = imgY + imgH + 1

local frameIdx      = 1
local lastFrameTime = os.clock()

local function drawBar(progress)
    local filled = math.floor(barWidth * progress)
    for x = 0, barWidth - 1 do
        term.setCursorPos(barX + x, barY)
        term.setBackgroundColor(x < filled and colors.lightBlue or colors.gray)
        term.write(" ")
    end
end

local function drawFrame(progress)
    local now = os.clock()
    if now - lastFrameTime >= 1 then
        frameIdx      = (frameIdx % #images) + 1
        lastFrameTime = now
    end
    term.setBackgroundColor(colors.black)
    term.clear()
    paintutils.drawImage(images[frameIdx], imgX, imgY)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(textX, textY)
    term.write(labelText)
    drawBar(progress)
end

-- ── Download ──────────────────────────────────────────────────
local total = #toDownload

for idx, mFile in ipairs(toDownload) do
    drawFrame((idx - 1) / total)

    local localPath = fs.combine(mFile.dir, mFile.name)
    local dir       = mFile.dir

    -- ensure all parent dirs exist
    local built = ""
    for part in dir:gmatch("[^/]+") do
        built = built == "" and part or (built .. "/" .. part)
        if not fs.exists(built) then fs.makeDir(built) end
    end

    local fRes = http.get(mFile.url)
    if fRes then
        local f = fs.open(localPath, "w")
        if f then f.write(fRes.readAll()); f.close() end
        fRes.close()
    end

    drawFrame(idx / total)
    sleep(0.5)
end

-- ── Post-download ─────────────────────────────────────────────
if isUpdate or not integrityOk then
    local fwrdVal = "none"
    local fwrRes  = http.get(FWRD_URL)
    if fwrRes then fwrdVal = fwrRes.readAll():gsub("%s+", ""); fwrRes.close() end

    config.version = remoteVersion or config.version
    config.fwrd    = fwrdVal

    local f = fs.open(INF_PATH, "w")
    if f then f.write(textutils.serialize(config)); f.close() end

    if not integrityOk and not isUpdate then
        os.pullEvent = nativePull
        local verfailOk = false
        if fs.exists(VERFAIL_SCRIPT) then
            local hRes2 = http.get(HASH_URL)
            if hRes2 then
                local remoteHashes = textutils.unserializeJSON(hRes2.readAll())
                hRes2.close()
                if type(remoteHashes) == "table" then
                    local expectedHash = remoteHashes["fw/warn/verfail.lua"]
                        or remoteHashes["/fw/warn/verfail.lua"]
                    if expectedHash then
                        local vf = fs.open(VERFAIL_SCRIPT, "r")
                        if vf then
                            local vContent = vf.readAll() or ""; vf.close()
                            verfailOk = calculateHash(vContent) == expectedHash
                        end
                    else
                        verfailOk = true
                    end
                end
            else
                verfailOk = true
            end
        end

        local function inlineFallback(reason)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.red)
            term.clear(); term.setCursorPos(1, 1)
            print("INTEGRITY FAIL")
            term.setTextColor(colors.white)
            print(reason)
            print("wiki.gghjk.net/cs/gvb/5004")
            while true do os.pullEventRaw() end
        end

        if not verfailOk then
            inlineFallback("verfail.lua is missing or corrupt.")
        else
            local ok2, runErr = pcall(shell.run, VERFAIL_SCRIPT)
            if not ok2 then
                inlineFallback("verfail.lua crashed: " .. tostring(runErr):sub(1, 38))
            end
        end
        return
    end

    os.reboot()
end

os.pullEvent = nativePull
if fs.exists(PRELOADER) then shell.run(PRELOADER) else os.reboot() end
