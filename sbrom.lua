local function calculateHash(str)
    str = str:gsub("\r", "")
    local hVal = 4021
    for i = 1, #str do
        hVal = ((hVal * 33) + str:byte(i)) % 2^32
    end
    return string.format("%08x", hVal)
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
local INF_PATH = "/fw/inf.conf"
local PRELOADER = "/fw/preloader.autorun"
local VERFAIL_SCRIPT = "/fw/warn/verfail.lua"

local function loadConfig()
    if not fs.exists(INF_PATH) then
        return { version = 0, unlocked = "no" }
    end
    local f = fs.open(INF_PATH, "r")
    if not f then return { version = 0, unlocked = "no" } end
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
term.setCursorPos(1, 1)
print("[ CC-Firmware integrity check ]")
print("")

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

-- DEBUG: počítadla
local countOk = 0
local countFail = 0
local countMissing = 0
local countSkipped = 0

for path, expectedHash in pairs(remoteHashes) do
    local localPath = path
    if not (localPath:sub(1,3) == "fw/" or localPath:sub(1,4) == "/fw/") then
        localPath = fs.combine("fw", path)
    end

    if not fs.exists(localPath) then
        if not localPath:find("inf.conf") then
            -- soubor chybí, zkusíme opravit
            term.setTextColor(colors.yellow)
            print("  MISSING  " .. localPath)
            term.setTextColor(colors.white)
            countMissing = countMissing + 1

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
                        term.setTextColor(colors.lime)
                        print("  REPAIRED " .. localPath)
                        term.setTextColor(colors.white)
                        repaired = true
                    end
                    break
                end
            end
        else
            -- inf.conf přeskočíme
            term.setTextColor(colors.gray)
            print("  SKIPPED  " .. localPath)
            term.setTextColor(colors.white)
            countSkipped = countSkipped + 1
        end
    else
        local f = fs.open(localPath, "r")
        if f then
            local content = f.readAll() or ""
            f.close()
            local actualHash = calculateHash(content)
            if actualHash == expectedHash then
                term.setTextColor(colors.lime)
                print("  OK       " .. localPath .. "  [" .. actualHash .. "]")
                term.setTextColor(colors.white)
                countOk = countOk + 1
            else
                term.setTextColor(colors.red)
                print("  FAIL     " .. localPath)
                print("    expected: " .. expectedHash)
                print("    got:      " .. actualHash)
                term.setTextColor(colors.white)
                countFail = countFail + 1
                integrityOk = false
                -- odstraň break pokud chceš vidět VŠECHNY chybné soubory
                break
            end
        end
    end
end

-- Shrnutí
print("")
print(string.format("OK: %d  FAIL: %d  MISSING: %d  SKIPPED: %d", countOk, countFail, countMissing, countSkipped))
print("")

if repaired then
    print("Opraveno, rebootuji...")
    sleep(2)
    os.reboot()
end

if not integrityOk then
    term.setTextColor(colors.red)
    print("Integrita selhala! System zamcen.")
    term.setTextColor(colors.white)
    os.pullEvent = nativePull
    while true do os.pullEventRaw() end
end

os.pullEvent = nativePull
print("Integrita OK, spoustim firmware...")
sleep(1)
if fs.exists(PRELOADER) then
    shell.run(PRELOADER)
else
    os.reboot()
end
