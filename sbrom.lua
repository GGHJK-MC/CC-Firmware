local function calculateHash(str)
    str = str:gsub("\r", "")
    local hVal = 4021
    for i = 1, #str do
        hVal = ((hVal * 33) + str:byte(i)) % 2^32
    end
    return string.format("%08x", hVal)
end

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

local socketPath = "/disk/sbrom.socket"
local payloadPath = "/disk/payload.sbrom"
local certHash = "5cd61823"

if fs.exists(socketPath) then
    local f = fs.open(socketPath, "r")
    if f then
        local content = f.readAll() or ""
        f.close()
        local fileHash = calculateHash(content)
        if fileHash == certHash then
            if fs.exists(payloadPath) then
                shell.run(payloadPath)
            end
        end
    end
end

local undevurl = http.get("https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/refs/heads/master/dev.json")
if not undevurl then return end
local unlockd = textutils.unserializeJSON(undevurl.readAll())
undevurl.close()
local id = os.getComputerID()
local unstate = unlockd["pc" .. id] or "no"
local nativePull = os.pullEvent
os.pullEvent = os.pullEventRaw

local HASH_URL = "https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/master/gvbchechsum.json"
local MANIFEST_URL = "https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/master/installmn.json"
local VERSION_URL = "https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/master/ver.txt"
local FWRD_URL = "https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/master/fwrd.txt"
local INF_PATH = "/fw/inf.conf"
local PRELOADER = "/fw/preloader.autorun"
local VERFAIL_SCRIPT = "/fw/warn/verfail.lua"

if not fs.exists(INF_PATH) then
    if not fs.exists("/fw") then fs.makeDir("/fw") end
    local inf_temp_url = http.get("https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/master/fw/inf.conf")
    local inf_temp_file = fs.open(INF_PATH, "w")
    inf_temp_file.write(inf_temp_url.readAll())
    inf_temp_file.close()
    inf_temp_url.close()
end

local function loadConfig()
    if not fs.exists(INF_PATH) then
        return { version = 0 }
    end
    local f = fs.open(INF_PATH, "r")
    if not f then return { version = 0, unlocked = "no" } end
    local data = textutils.unserialize(f.readAll())
    f.close()
    return data or { version = 0, unlocked = "no" }
end

local config = loadConfig()

local vRes = http.get(VERSION_URL)
local remoteVersion = vRes and vRes.readAll():gsub("%s+", "") or nil
if vRes then vRes.close() end

local localVersion = tostring(config.version or "0")

local isUpdate = false
if remoteVersion and isNewerVersion(remoteVersion, localVersion) then
    isUpdate = true
    local files = fs.list("/fw")
    for _, file in ipairs(files) do
        if file ~= "inf.conf" then
            fs.delete(fs.combine("/fw", file))
        end
    end
elseif remoteVersion and not isNewerVersion(remoteVersion, localVersion) then
    os.pullEvent = nativePull
    if fs.exists(PRELOADER) then
        shell.run(PRELOADER)
    else
        os.reboot()
    end
    return
end

local hRes = http.get(HASH_URL)
local mRes = http.get(MANIFEST_URL)
if not hRes or not mRes then
    os.pullEvent = nativePull
    if fs.exists(PRELOADER) then
        shell.run(PRELOADER)
    else
        os.reboot()
    end
    return
end

local remoteHashes = textutils.unserializeJSON(hRes.readAll())
local manifest = textutils.unserializeJSON(mRes.readAll())
hRes.close()
mRes.close()

local integrityOk = true
local repaired = false

for path, expectedHash in pairs(remoteHashes) do
    local localPath = path
    if not (localPath:sub(1,3) == "fw/" or localPath:sub(1,4) == "/fw/") then
        localPath = fs.combine("fw", path)
    end
    if not fs.exists(localPath) then
        if not localPath:find("inf.conf") then
            local fileName = fs.getName(localPath)
            for _, mFile in ipairs(manifest) do
                if mFile.name == fileName then
                    local fRes = http.get(mFile.url)
                    if fRes then
                        local dir = localPath:match("(.+)/")
                        if dir and not fs.exists(dir) then
                            fs.makeDir(dir)
                        end
                        local f = fs.open(localPath, "w")
                        f.write(fRes.readAll())
                        f.close()
                        fRes.close()
                        repaired = true
                    end
                    break
                end
            end
        end
    else
        local f = fs.open(localPath, "r")
        if f then
            local content = f.readAll() or ""
            f.close()
            if calculateHash(content) ~= expectedHash then
                integrityOk = false
                break
            end
        end
    end
end

if isUpdate then
    local fwrdVal = "none"
    local fwrRes = http.get(FWRD_URL)
    if fwrRes then
        fwrdVal = fwrRes.readAll():gsub("%s+", "")
        fwrRes.close()
    end
    config.version = remoteVersion
    config.fwrd = fwrdVal
    local f = fs.open(INF_PATH, "w")
    f.write(textutils.serialize(config))
    f.close()
    os.reboot()
end

if repaired then
    os.reboot()
end

if not integrityOk then
    os.pullEvent = nativePull
    if fs.exists(VERFAIL_SCRIPT) == true then
        shell.run(VERFAIL_SCRIPT)
    else
        while true do os.pullEventRaw() end
    end
end

if remoteVersion then
    local cfg = loadConfig()
    cfg.version = remoteVersion
    local f = fs.open(INF_PATH, "w")
    f.write(textutils.serialize(cfg))
    f.close()
end

os.pullEvent = nativePull
if fs.exists(PRELOADER) then
    shell.run(PRELOADER)
else
    os.reboot()
end