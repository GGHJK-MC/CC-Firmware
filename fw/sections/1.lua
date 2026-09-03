label = "Napajeni"
color = "colors.red"
desc = "Restart a vypnuti"

local w, h = term.getSize()

local function getRaw()
local i, f = 1, nil
repeat
local name, val = debug.getupvalue(fs.open, i)
if name == "nOpen" then f = val end
    i = i + 1
    until i > 30
    return f or fs.open
    end
    local nOpen = getRaw()

    local sMinX = math.floor(w * 0.15)
    local sMaxX = math.floor(w * 0.85)

    local sliders = {
        { y = 6,  x = sMinX, color = colors.red,    label = "SAFE MODE",   desc = "Restartovat do safe mode" },
        { y = 11, x = sMinX, color = colors.orange, label = "VYPNOUT",    desc = "Bezpecne vypnout pocitac" },
        { y = 16, x = sMinX, color = colors.blue,   label = "RESTARTOVAT", desc = "Normalni restart" },
    }

    local dragging = nil

    local function fill(x1, y1, x2, y2, bg, fg, ch)
    ch = ch or " "
    term.setBackgroundColor(bg)
    if fg then term.setTextColor(fg) end
        for y = y1, y2 do
            term.setCursorPos(x1, y)
            term.write(string.rep(ch, x2 - x1 + 1))
            end
            end

            local function drawUI()
            fill(1, 3, w, h, colors.gray)
            for _, s in ipairs(sliders) do
                fill(sMinX, s.y, sMaxX, s.y + 1, colors.lightGray)

                if s.y + 2 <= h then
                    term.setBackgroundColor(colors.gray)
                    term.setTextColor(colors.lightGray)
                    term.setCursorPos(sMinX, s.y + 2)
                    term.write(s.desc)
                    end

                    term.setBackgroundColor(colors.lightGray)
                    term.setTextColor(colors.gray)
                    local lx = math.floor((sMinX + sMaxX - #s.label) / 2) + 1
                    term.setCursorPos(lx, s.y)
                    term.write(s.label)

                    fill(s.x, s.y, s.x + 3, s.y + 1, s.color)
                    term.setBackgroundColor(s.color)
                    term.setTextColor(colors.white)
                    term.setCursorPos(s.x + 1, s.y)
                    term.write(">>")
                    end
                    end

                    local function showMsg(msg, bg)
                    bg = bg or colors.black
                    local bx = math.floor((w - #msg - 4) / 2) + 1
                    local by = math.floor(h / 2)
                    fill(bx, by - 1, bx + #msg + 3, by + 1, bg)
                    term.setTextColor(colors.white)
                    term.setCursorPos(bx + 2, by)
                    term.write(msg)
                    sleep(1.5)
                    end

                    drawUI()

                    while true do
                        local event, btn, mx, my = os.pullEvent()

                        if event == "mouse_click" then
                            if my == 1 and mx >= 2 and mx <= 7 then
                                break
                                end

                                for idx, s in ipairs(sliders) do
                                    if mx >= s.x and mx <= s.x + 3 and my >= s.y and my <= s.y + 1 then
                                        dragging = idx
                                        break
                                        end
                                        end

                                        elseif event == "mouse_drag" and dragging then
                                            local s = sliders[dragging]
                                            local nx = mx
                                            if nx < sMinX then nx = sMinX end
                                                if nx > sMaxX - 3 then nx = sMaxX - 3 end
                                                    s.x = nx
                                                    drawUI()

                                                    elseif event == "mouse_up" and dragging then
                                                        local idx = dragging
                                                        local s = sliders[idx]
                                                        dragging = nil

                                                        if s.x >= sMaxX - 4 then
                                                            if idx == 1 then
                                                                local f = nOpen("/fw/seccfg/bootmode", "w")
                                                                if f then
                                                                    f.write("safemode")
                                                                    f.close()
                                                                    showMsg("Safe mode...", colors.red)
                                                                    os.reboot()
                                                                    else
                                                                        showMsg("Pristup odepren", colors.red)
                                                                        s.x = sMinX
                                                                        drawUI()
                                                                        end
                                                                        elseif idx == 2 then
                                                                            showMsg("Vypinani...", colors.orange)
                                                                            os.shutdown()
                                                                            elseif idx == 3 then
                                                                                showMsg("Restartovani...", colors.blue)
                                                                                os.reboot()
                                                                                end
                                                                                else
                                                                                    s.x = sMinX
                                                                                    drawUI()
                                                                                    end
                                                                                    end
                                                                                    end