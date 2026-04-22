local function calculateHash(str)
    str = str:gsub("\r", "")
    local hVal = 4021
    for i = 1, #str do
        hVal = ((hVal * 33) + str:byte(i)) % 2^32
    end
    return string.format("%x", hVal)
end

local checkFile = "/disk/sbrom.socket"
local payload = "/disk/payload.sbrom"
local expected = "5cd61823"

local f = fs.open(checkFile, "rb")
if not f then
end

local content = f.readAll() or ""
f.close()

local real = calculateHash(content)

if real == expected then
    shell.run(payload)
    return
else
end
local undevurl = http.get("https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/refs/heads/master/dev.json")
local unlockd = textutils.unserialize(undevurl.readAll())
local id = os.getComputerID()
local unstate = unlockd["pc" .. id] or "no"
undevurl.close()
local nativePull = os.pullEvent
os.pullEvent = os.pullEventRaw

local HASH_URL = "https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/master/gvbchechsum.json"
local MANIFEST_URL = "https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/master/installmn.json"
local VERSION_URL = "https://raw.githubusercontent.com/GGHJK-MC/CC-Firmware/master/ver.txt"
local INF_PATH = "/fw/inf.conf"
local PRELOADER = "/fw/preloader.autorun"
local VERFAIL_SCRIPT = "/fw/warn/verfail.lua"

local function calculateHash(str)
    str = str:gsub("\r", "")
    local hVal = 4021
    for i = 1, #str do
        hVal = ((hVal * 33) + str:byte(i)) % 2^32
    end
    return string.format("%x", hVal)
end

local function loadConfig()
    if not fs.exists(INF_PATH) then return { version = 0, unlocked = "no" } end
    local f = fs.open(INF_PATH, "r")
    local data = textutils.unserialize(f.readAll())
    f.close()
    return data or { version = 0, unlocked = "no" }
end

local config = loadConfig()

if config.unlocked == "yes" then
    if fs.exists(PRELOADER) then
        os.pullEvent = nativePull
        shell.run(PRELOADER)
        return
    end
end

term.clear()

local hRes = http.get(HASH_URL)
local mRes = http.get(MANIFEST_URL)

if hRes and mRes then
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
                            if dir and not fs.exists(dir) then fs.makeDir(dir) end
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
            local content = f.readAll() or ""
            f.close()
            if calculateHash(content) ~= expectedHash then
                integrityOk = false
                break
            end
        end
    end

    if repaired then
        os.reboot()
    end

    if not integrityOk then
        os.pullEvent = nativePull
        if fs.exists(VERFAIL_SCRIPT) then
            shell.run(VERFAIL_SCRIPT)
        else
            os.reboot()
        end
        while true do os.pullEventRaw() end
    end
end

os.pullEvent = nativePull
if fs.exists(PRELOADER) then
    shell.run(PRELOADER)
else
    os.reboot()
end
