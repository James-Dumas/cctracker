width = 51
height = 19

local w, h = term.getSize()
if w ~= width or h ~= height or not term.isColor() then
    error("Please run on an advanced computer.")
end

speaker = peripheral.find("speaker")
if not speaker then
    error("No speaker connected.")
end

panels = {}
song = {
    frames = {},
    order = {[0] = 0},
    getFrameAt = function(self, index)
        return self.frames[self.order[index]]
    end
}

selection = {
    ir = nil, -- initially selected row
    ic = nil, -- initially selected column
    r1 = nil, -- min row
    c1 = nil, -- min column
    r2 = nil, -- max row
    c2 = nil, -- max column
    data = nil -- zero-indexed slice of song
}

clipboard = nil -- zero-indexed slice of song

muted = {false, false, false, false, false, false, false} -- which channels are muted

options = {
    frames = 1,
    rows = 16,
    speed = 4,

    editingFrames = nil,
    editingRows = nil,
    editingSpeed = nil,

    currentFrame = 0,
    currentRow = 1,
    currentChannel = 1,
    currentItem = "note",
    currentInstrument = 1,

    minFrames = 1,
    maxFrames = 256,
    minRows = 4,
    maxRows = 64,
    minSpeed = 1,
    maxSpeed = 20,

    panel = "header",
    name = "New Song",
    filename = "",
    tempFilename = "",

    exit = false,
    shift = false,
    stop = false,
    selecting = false
}

noteKeys = {
    a = 0,
    z = 1,
    s = 2,
    x = 3,
    d = 4,
    c = 5,
    v = 6,
    g = 7,
    b = 8,
    h = 9,
    n = 10,
    m = 11,
    k = 12,
    comma = 13,
    l = 14,
    period = 15,
    colon = 16,
    slash = 17,
    one = 12,
    q = 13,
    two = 14,
    w = 15,
    three = 16,
    e = 17,
    r = 18,
    five = 19,
    t = 20,
    six = 21,
    y = 22,
    u = 23,
    eight = 24
}

noteNames = {[0] = "F#", "G-", "G#", "A-", "A#", "B-", "C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-", "C-", "C#", "D-", "D#", "E-", "F-", "F#"}

instruments = {
    {"bass", 1, "Bass"},
    {"snare", 1, "Snare"},
    {"hat", 1, " Hat"},
    {"basedrum", 1, "Kick"},
    {"bell", 5, "Bell"},
    {"flute", 4, "Flute"},
    {"chime", 5, "Chime"},
    {"guitar", 2, "Guitr"},
    {"xylophone", 5, "Xlphn"},
    {"iron_xylophone", 3, "Vbrph"},
    {"cow_bell", 4, "CwBll"},
    {"didgeridoo", 1, "Dgrdo"},
    {"bit", 3, "Squar"},
    {"banjo", 3, "Banjo"},
    {"pling", 3, "ElPno"},
    {"harp", 3, "Piano"}
}

digitSet = {["0"] = true, ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true, ["5"] = true, ["6"] = true, ["7"] = true, ["8"] = true, ["9"] = true}
hexDigitSet = {["zero"] = true, ["one"] = true, ["two"] = true, ["three"] = true, ["four"] = true, ["five"] = true, ["six"] = true, ["seven"] = true, ["eight"] = true, ["nine"] = true, ["a"] = true, ["b"] = true, ["c"] = true, ["d"] = true, ["e"] = true, ["f"] = true}
hexDigitMap = {["zero"] = 0, ["one"] = 1, ["two"] = 2, ["three"] = 3, ["four"] = 4, ["five"] = 5, ["six"] = 6, ["seven"] = 7, ["eight"] = 8, ["nine"] = 9, ["a"] = "a", ["b"] = "b", ["c"] = "c", ["d"] = "d", ["e"] = "e", ["f"] = "f"}

function hex2dec(hex)
    return tonumber("0x" .. hex)
end

function dec2hex(num)
    return string.upper(string.format("%x", num))
end

function zeroPad(num, len)
    out = num
    for i = 1, len - string.len(num) do
        out = "0" .. out
    end
    return out
end

function deleteFromString(str)
    if string.len(str) == 0 then
        return "", false
    else
        return string.sub(str, 1, -2), true
    end
end

function getDisplayNote(note)
    local octave = instruments[note[2]][2]
    if octave == -1 then
        octave = "-"
    else
        if note[1] > 5 then octave = octave + 1 end
        if note[1] > 17 then octave = octave + 1 end
    end
    return noteNames[note[1]] .. octave
end

function isEmptyNestedTable(t)
    allEmpty = true
    for k, v in pairs(t) do
        if type(v) ~= "table" then
            return false
        else
            allEmpty = allEmpty and isEmptyNestedTable(v)
        end
    end
    return allEmpty
end

function playNotes(notes)
    for i, note in pairs(notes) do
        if not muted[i] and instruments[note[2]][4] then
            speaker.playNote(instruments[note[2]][1], note[3] / 15, note[1])
        end
    end
end

function newFrame()
    local frame = {}
    for r = 1, options.rows do
        frame[r] = {}
    end
    return frame
end

function updateSelection()
    selection.data = {}
    selection.r1 = math.min(selection.ir, options.currentRow)
    selection.c1 = math.min(selection.ic, options.currentChannel)
    selection.r2 = math.max(selection.ir, options.currentRow)
    selection.c2 = math.max(selection.ic, options.currentChannel)
    local frame = song:getFrameAt(options.currentFrame)
    for r = selection.r1, selection.r2 do
        selection.data[r - selection.r1] = {}
        for c = selection.c1, selection.c2 do
            local note = frame[r][c]
            if note ~= nil then
                selection.data[r - selection.r1][c - selection.c1] = {note[1], note[2], note[3]}
            end
        end
    end
    panels.editor.needsRedraw = true
end

function clearSelection()
    selection = {}
    options.selecting = false
    panels.editor.needsRedraw = true
end

function stepRow(up)
    if up then
        if options.currentRow == 1 then
            if not options.selecting then
                options.currentRow = options.rows
                if options.currentFrame == 0 then
                    options.currentFrame = options.frames - 1
                else
                    options.currentFrame = options.currentFrame - 1
                end
                panels.frames.needsRedraw = true
            end
        else
            options.currentRow = options.currentRow - 1
        end
        panels.editor.needsRedraw = true
    else
        if options.currentRow == options.rows then
            if not options.selecting then
                options.currentRow = 1
                if options.currentFrame == options.frames - 1 then
                    options.currentFrame = 0
                else
                    options.currentFrame = options.currentFrame + 1
                end
                panels.frames.needsRedraw = true
            end
        else
            options.currentRow = options.currentRow + 1
        end
        panels.editor.needsRedraw = true
    end
end

function saveSong(filename)
    local outfile = io.open(filename, "w")
    outfile:write("cctracker\n")
    outfile:write(options.name .. "\n")
    outfile:write(options.speed .. "\n")
    outfile:write(options.frames .. "\n")
    outfile:write(options.rows .. "\n")
    outfile:write(options.currentInstrument .. "\n")
    local mutedString = ""
    for i = 1, 7 do
        mutedString = mutedString .. (muted[i] and "1" or "0")
    end
    local orderString = ""
    outfile:write(mutedString .. "\n")
    for i = 0, options.frames - 1 do
        orderString = orderString .. song.order[i] .. " "
    end
    outfile:write(string.sub(orderString, 1, -2) .. "\n")
    for fi, frame in pairs(song.frames) do
        if not isEmptyNestedTable(frame) then
            outfile:write("f" .. fi .. "\n")
            for ri, row in pairs(song.frames[fi]) do
                if not isEmptyNestedTable(row) then
                    outfile:write("r" .. ri .. "\n")
                    for ci, note in pairs(song.frames[fi][ri]) do
                        outfile:write("c" .. ci .. "\n")
                        outfile:write(note[1] .. " " .. note[2] .. " " .. note[3] .. "\n")
                    end
                end
            end
        end
    end
    io.close(outfile)
end

function loadSong(filename)
    local infile = io.open(filename, "r")
    local lineNum = 1
    local status = {
        frame = 0,
        row = 1,
        chan = 1
    }
    for line in infile:lines() do
        if lineNum == 1 and line ~= "cctracker" then
            return "Not a cctracker file."
        elseif lineNum == 2 then
            options.name = line
        elseif lineNum == 3 then
            options.speed = tonumber(line)
        elseif lineNum == 4 then
            options.frames = tonumber(line)
        elseif lineNum == 5 then
            options.rows = tonumber(line)
        elseif lineNum == 6 then
            options.currentInstrument = tonumber(line)
        elseif lineNum == 7 then 
            for i = 1, 7 do
                muted[i] = string.sub(line, i, i) == "1"
            end
        elseif lineNum == 8 then
            song.order = {}
            song.frames = {}
            local i = 0
            for num in string.gmatch(line, "[^%s]+") do
                song.order[i] = tonumber(num)
                i = i + 1
            end
        else
            if string.len(line) > 1 then
                local char = string.sub(line, 1, 1)
                local num = string.sub(line, 2, -1)
                if char == "f" then
                    status.frame = tonumber(num)
                    song.frames[status.frame] = newFrame()
                elseif char == "r" then
                    status.row = tonumber(num)
                elseif char == "c" then
                    status.chan = tonumber(num)
                else
                    local note = {}
                    for val in string.gmatch(line, "[^%s]+") do
                        table.insert(note, tonumber(val))
                    end
                    song.frames[status.frame][status.row][status.chan] = note
                end
            end
        end
        lineNum = lineNum + 1
    end
    for i = 0, options.frames - 1 do
        if song.frames[song.order[i]] == nil then
            song.frames[song.order[i]] = newFrame()
        end
    end
    io.close(infile)
    clearSelection()
    options.currentFrame = 0
    options.currentRow = 1
    options.currentChannel = 1
    options.currentItem = "note"
end

function exportSong()
end

function isOkFilename(filename)
    if string.len(filename) == 0 then
        return false
    end
    local ok = true
    for i = 1, string.len(filename) do
        local char = string.sub(filename, i, i)
        ok = ok and char ~= " " and char ~= "/" and char ~= "\\"
    end
    return ok
end

function fileExists(filename)
    local file = io.open(filename, "r")
    if file ~= nil then 
        io.close(file) 
        return true 
    else 
        return false 
    end
end

function playSong()
    clearSelection()
    options.currentRow = 1
    options.stop = false
    panels.editor.needsRedraw = true
    redrawPanels()
    local t = 0.001 -- one tick
    local time = os.time()
    local alarmTime = time + t
    os.setAlarm(alarmTime)
    while not options.stop do
        os.pullEvent("alarm")
        time = os.time()
        alarmTime = (time + t * options.speed) % 24
        os.setAlarm(alarmTime)
        playNotes(song:getFrameAt(options.currentFrame)[options.currentRow])
        redrawPanels()
        stepRow()
    end
end

function waitForStop()
    options.shift = false
    while true do
        local event, key = os.pullEvent("key")
        local x, y = panels[options.panel].window.getCursorPos()
        if key == keys.space or (options.panel == "header" and x == 19 and y == 2 and key == keys.enter) then
            break
        end
    end
    options.stop = true
end

function redrawPanels()
    local x, y = panels[options.panel].window.getCursorPos()
    for name, panel in pairs(panels) do
        if panel.needsRedraw then
            panel:redraw()
            panel.needsRedraw = false
        end
    end 
    panels[options.panel].window.setCursorPos(x, y)
end

function main()
    redrawPanels()
    while not options.exit do
        -- get input and perform action
        local event, param1, param2 = os.pullEvent()
        if event == "key" then
            if param1 == keys.leftShift then
                options.shift = true
            end
            if options.shift and hexDigitSet[keys.getName(param1)] and (options.panel == "editor" or options.panel == "frames") then
                options.currentInstrument = hex2dec(hexDigitMap[keys.getName(param1)]) + 1
                playNotes({{6, options.currentInstrument, 11}})
                panels.frames.needsRedraw = true
            elseif options.shift and param1 == keys.space and (options.panel == "editor" or options.panel == "frames") then
                options.currentFrame = 0
                panels.frames.needsRedraw = true
                parallel.waitForAll(playSong, waitForStop)
            elseif param1 == keys.space and (options.panel == "editor" or options.panel == "frames") then
                parallel.waitForAll(playSong, waitForStop)
            else
                panels[options.panel]:doAction(event, param1)
            end
        elseif event == "char" then
            panels[options.panel]:doAction(event, param1)
        elseif event == "key_up" then
            if param1 == keys.leftShift then
                options.shift = false
            end
        end
        -- display
        redrawPanels()
    end
end

function init()
    song.frames[0] = newFrame()

    -- create panels
    panels.header = {
        window = window.create(term.current(), 1, 1, width, 3),
        needsRedraw = true,
        gotoDefaultPosition = function(self)
            options.panel = "header"
            self.window.setCursorPos(19, 2)
        end,
        redraw = function(self)
            self.window.clear()
            self.window.setCursorBlink(false)
            self.window.setCursorPos(2, 2)
            self.window.setTextColor(colors.lightBlue)
            self.window.write("SAVE LOAD ")
            self.window.setTextColor(colors.yellow)
            self.window.write("EXPORT ")
            self.window.setTextColor(colors.lime)
            self.window.write("PLAY ")
            self.window.setTextColor(colors.red)
            self.window.write("QUIT")
            self.window.setTextColor(colors.white)
            self.window.setCursorPos(2, 1)
            self.window.write("Name: " .. options.name)
            self.window.setCursorPos(42, 1)
            self.window.write("Speed: " .. (options.editingSpeed or zeroPad(options.speed, 2)))
            self.window.setCursorPos(30, 2)
            self.window.write("Frames: " .. (options.editingFrames or zeroPad(options.frames, 3)))
            self.window.setCursorPos(43, 2)
            self.window.write("Rows: " .. (options.editingRows or zeroPad(options.rows, 2)))
            self.window.setCursorPos(1, 3)
            self.window.write("---------------------------------------------------")
            self.window.setCursorBlink(true)
        end,
        doAction = function(self, event, param)
            local x, y = self.window.getCursorPos()

            local updateSpeed = function()
                if options.editingSpeed == "" then
                    options.editingSpeed = 0
                end
                if options.editingSpeed ~= nil and options.editingSpeed ~= options.speed then
                    options.speed = math.min(options.maxSpeed, math.max(options.minSpeed, tonumber(options.editingSpeed)))
                    panels.header.needsRedraw = true
                end
                options.editingSpeed = nil
            end

            local updateFrames = function()
                if options.editingFrames == "" then
                    options.editingFrames = 0
                end
                if options.editingFrames ~= nil and options.editingFrames ~= options.frames then
                    local oldFrameNum = options.frames
                    options.frames = math.min(options.maxFrames, math.max(options.minFrames, tonumber(options.editingFrames)))
                    if options.frames > oldFrameNum then
                        for i = oldFrameNum + 1, options.frames do
                            if song.order[i - 1] == nil then
                                song.order[i - 1] = 0
                            end
                        end
                    end
                    panels.header.needsRedraw = true
                    panels.frames.needsRedraw = true
                end
                options.editingFrames = nil
            end

            local updateRows = function()
                if options.editingRows == "" then
                    options.editingRows = 0
                end
                if options.editingRows ~= nil and options.editingRows ~= options.rows then
                    local oldRowNum = options.rows
                    options.rows = math.min(options.maxRows, math.max(options.minRows, tonumber(options.editingRows)))
                    for i, frameHere in pairs(song.frames) do
                        if options.rows > oldRowNum then
                            for i = oldRowNum + 1, options.rows do
                                if frameHere[i] == nil then
                                    frameHere[i] = {}
                                end
                            end
                        else
                            for i = options.rows + 1, oldRowNum do
                                if isEmptyNestedTable(frameHere[i]) then
                                    frameHere[i] = nil
                                end
                            end
                        end
                    end
                    if options.currentRow > options.rows then
                        options.currentRow = options.rows
                    end
                    panels.header.needsRedraw = true
                    panels.editor.needsRedraw = true
                end
                options.editingRows = nil
            end

            if options.shift == true then
                if event == "key" and param == keys.down then
                    updateSpeed()
                    updateFrames()
                    updateRows()
                    panels.editor:gotoDefaultPosition()
                end
            end
            if y == 1 then
                if x < 42 then -- editing name
                    if event == "key" then
                        if param == keys.backspace then
                            local ok
                            options.name, ok = deleteFromString(options.name)
                            if ok then
                                self.window.setCursorPos(x - 1, y)
                                self.needsRedraw = true
                            end
                        elseif param == keys.right then
                            self.window.setCursorPos(51, 1)
                        elseif param == keys.down and not options.shift then
                            self.window.setCursorPos(19, 2)
                        end
                    elseif event == "char" and x < 41 then
                        options.name = options.name .. param
                        self.window.setCursorPos(x + 1, y)
                        self.needsRedraw = true
                    end
                elseif x > 48 then -- editing speed
                    if event == "key" then
                        if param == keys.backspace then
                            local ok
                            options.editingSpeed, ok = deleteFromString(options.editingSpeed or zeroPad(options.speed, 2))
                            if ok then
                                self.window.setCursorPos(x - 1, y)
                                self.needsRedraw = true
                            end
                        elseif param == keys.left then
                            updateSpeed()
                            self.window.setCursorPos(8 + string.len(options.name), 1)
                            self.needsRedraw = true
                        elseif param == keys.down then
                            updateSpeed()
                            self.window.setCursorPos(51, 2)
                            self.needsRedraw = true
                        end
                    elseif event == "char" and x < 51 and digitSet[param] then
                        options.editingSpeed = tonumber((options.editingSpeed or options.speed) .. param)
                        self.window.setCursorPos(49 + string.len(options.editingSpeed), y)
                        self.needsRedraw = true
                    end
                end
            else -- y = 2
                if x == 2 then -- SAVE
                    if event == "key" then
                        if param == keys.enter or param == keys.space then
                            panels.saveFile:gotoDefaultPosition()
                        elseif param == keys.right then
                            self.window.setCursorPos(7, 2)
                        elseif param == keys.up then
                            self.window.setCursorPos(8 + string.len(options.name), 1)
                        end
                    end
                elseif x == 7 then -- LOAD
                    if event == "key" then
                        if param == keys.enter or param == keys.space then
                            panels.loadFile:gotoDefaultPosition()
                        elseif param == keys.left then
                            self.window.setCursorPos(2, 2)
                        elseif param == keys.right then
                            self.window.setCursorPos(12, 2)
                        elseif param == keys.up then
                            self.window.setCursorPos(8 + string.len(options.name), 1)
                        end
                    end
                elseif x == 12 then -- EXPORT
                    if event == "key" then
                        if param == keys.enter or param == keys.space then
                            exportSong()
                        elseif param == keys.left then
                            self.window.setCursorPos(7, 2)
                        elseif param == keys.right then
                            self.window.setCursorPos(19, 2)
                        elseif param == keys.up then
                            self.window.setCursorPos(8 + string.len(options.name), 1)
                        end
                    end
                elseif x == 19 then -- PLAY
                    if event == "key" then
                        if param == keys.enter or param == keys.space then
                            parallel.waitForAll(playSong, waitForStop)
                        elseif param == keys.left then
                            self.window.setCursorPos(12, 2)
                        elseif param == keys.right then
                            self.window.setCursorPos(24, 2)
                        elseif param == keys.up then
                            self.window.setCursorPos(8 + string.len(options.name), 1)
                        end
                    end
                elseif x == 24 then -- QUIT
                    if event == "key" then
                        if param == keys.enter or param == keys.space then
                            options.exit = true
                        elseif param == keys.left then
                            self.window.setCursorPos(19, 2)
                        elseif param == keys.right then
                            self.window.setCursorPos(41, 2)
                        elseif param == keys.up then
                            self.window.setCursorPos(8 + string.len(options.name), 1)
                        end
                    end
                elseif x < 42 then -- editing frames
                    if event == "key" then
                        if param == keys.backspace then
                            local ok
                            options.editingFrames, ok = deleteFromString(options.editingFrames or zeroPad(options.frames, 3))
                            if ok then
                                self.window.setCursorPos(x - 1, y)
                                self.needsRedraw = true
                            end
                        elseif param == keys.left then
                            updateFrames()
                            self.window.setCursorPos(24, 2)
                            self.needsRedraw = true
                        elseif param == keys.right then
                            updateFrames()
                            self.window.setCursorPos(51, 2)
                            self.needsRedraw = true
                        elseif param == keys.up then
                            updateFrames()
                            self.window.setCursorPos(8 + string.len(options.name), 1)
                            self.needsRedraw = true
                        end
                    elseif event == "char" and x < 41 and digitSet[param] then
                        options.editingFrames = tonumber((options.editingFrames or options.frames) .. param)
                        self.window.setCursorPos(38 + string.len(options.editingFrames), y)
                        self.needsRedraw = true
                    end
                elseif x > 48 then -- editing rows
                    if event == "key" then
                        if param == keys.backspace then
                            local ok
                            options.editingRows, ok = deleteFromString(options.editingRows or zeroPad(options.rows, 2))
                            if ok then
                                self.window.setCursorPos(x - 1, y)
                                self.needsRedraw = true
                            end
                        elseif param == keys.left then
                            updateRows()
                            self.window.setCursorPos(41, 2)
                            self.needsRedraw = true
                        elseif param == keys.up then
                            updateRows()
                            self.window.setCursorPos(51, 1)
                            self.needsRedraw = true
                        end
                    elseif event == "char" and x < 51 and digitSet[param] then
                        options.editingRows = tonumber((options.editingRows or options.rows) .. param)
                        self.window.setCursorPos(49 + string.len(options.editingRows), y)
                        self.needsRedraw = true
                    end
                end
            end
        end
    }
    panels.editor = {
        window = window.create(term.current(), 2, 4, 43, 16),
        needsRedraw = true,
        autoSetCursorPos = function(self)
            offset = 0
            if options.currentItem == "instrument" then
                offset = 3
            elseif options.currentItem == "volume" then
                offset = 4
            end
            self.window.setCursorPos(6 * (options.currentChannel - 1) + 2 + offset, 9)
        end,
        gotoDefaultPosition = function(self)
            options.panel = "editor"
            self:autoSetCursorPos()
        end,
        redraw = function(self)
            self.window.clear()
            self.window.setCursorBlink(false)
            self.window.setCursorPos(1, 1)
            self.window.write("|     |     |     |     |     |     |     |")
            for chan = 1, 7 do
                self.window.setCursorPos(6 * (chan - 1) + 3, 1)
                if muted[chan] then
                    self.window.blit("!" .. chan .. "!", "888", "fff")
                else
                    self.window.write(" " .. chan)
                end
            end

            for windowRow = 2, 16 do
                local dispRow = windowRow - 9 + options.currentRow
                local dispString = "|"
                local colorString = "8"
                local bgString = "f"
                if dispRow == options.currentRow then
                    colorString = "0"
                end
                if dispRow > 0 and dispRow <= options.rows then
                    for chan = 1, 7 do
                        local note = song:getFrameAt(options.currentFrame)[dispRow][chan]
                        if note ~= nil then
                            dispString = dispString .. getDisplayNote(note) .. dec2hex(note[2] - 1) .. dec2hex(note[3]) .. "|"
                            if instruments[note[2]][4] then
                                colorString = colorString .. "444530"
                            else
                                colorString = colorString .. "444e30"
                            end
                        else
                            dispString = dispString .. "-----|"
                            if dispRow == options.currentRow then
                                colorString = colorString .. "888880"
                            else
                                colorString = colorString .. "777778"
                            end
                        end
                        if options.selecting and dispRow >= selection.r1 and dispRow <= selection.r2 and chan >= selection.c1 and chan <= selection.c2 then
                            bgString = bgString .. "bbbbbf"
                        else
                            bgString = bgString .. "ffffff"
                        end
                    end
                    self.window.setCursorPos(1, windowRow)
                    self.window.blit(dispString, colorString, bgString)
                end
            end
            self.window.setCursorBlink(true)
        end,
        doAction = function(self, event, param)
            if options.shift then
                if event == "key" then
                    if param == keys.up then
                        clearSelection()
                        panels.header:gotoDefaultPosition()
                    elseif param == keys.right then
                        clearSelection()
                        panels.frames:gotoDefaultPosition()
                    elseif not options.selecting and param == keys.v and clipboard ~= nil then
                        options.currentItem = "note"
                        for ri, row in pairs(clipboard) do
                            if ri + options.currentRow <= options.rows then
                                for ci, note in pairs(row) do
                                    if ci + options.currentChannel <= 7 then
                                        local frame = song:getFrameAt(options.currentFrame)
                                        if note ~= nil then
                                            frame[ri + options.currentRow][ci + options.currentChannel] = {note[1], note[2], note[3]}
                                        end
                                    end
                                end
                            end
                        end
                        self:autoSetCursorPos()
                        self.needsRedraw = true
                    elseif not options.selecting and param == keys.m then
                        muted[options.currentChannel] = not muted[options.currentChannel]
                        self.needsRedraw = true
                    elseif param == keys.s then
                        if options.selecting then
                            clearSelection()
                        else
                            options.selecting = true
                            options.currentItem = "note"
                            self:autoSetCursorPos()
                            selection.ir = options.currentRow
                            selection.ic = options.currentChannel
                            updateSelection()
                        end
                    end
                end
            else
                if event == "key" then
                    if options.selecting then
                        if param == keys.up then
                            stepRow(true)
                            updateSelection()
                        elseif param == keys.down then
                            stepRow()
                            updateSelection()
                        elseif param == keys.left and options.currentChannel > 1 then
                            options.currentChannel = options.currentChannel - 1
                            updateSelection()
                            self:autoSetCursorPos()
                        elseif param == keys.right and options.currentChannel < 7 then
                            options.currentChannel = options.currentChannel + 1
                            updateSelection()
                            self:autoSetCursorPos()
                        elseif param == keys.c then
                            clipboard = selection.data
                            clearSelection()
                        elseif param == keys.x then
                            clipboard = selection.data
                            local frame = song:getFrameAt(options.currentFrame)
                            for r = selection.r1, selection.r2 do
                                for c = selection.c1, selection.c2 do
                                    frame[r][c] = nil
                                end
                            end
                            clearSelection()
                        elseif param == keys.a then
                            selection.ir = 1
                            selection.ic = 1
                            options.currentRow = options.rows
                            options.currentChannel = 7
                            updateSelection()
                            self:autoSetCursorPos()
                        elseif param == keys.z then
                            selection.ir = 1
                            selection.ic = options.currentChannel
                            options.currentRow = options.rows
                            updateSelection()
                            self:autoSetCursorPos()
                        end
                    else
                        if param == keys.up then
                            stepRow(true)
                        elseif param == keys.down then
                            stepRow()
                        elseif param == keys.left then
                            if options.currentItem == "note" and options.currentChannel > 1 then
                                options.currentChannel = options.currentChannel - 1
                                options.currentItem = "volume"
                            elseif options.currentItem == "instrument" then
                                options.currentItem = "note"
                            elseif options.currentItem == "volume" then
                                options.currentItem = "instrument"
                            end
                            self:autoSetCursorPos()
                        elseif param == keys.right then
                            if options.currentItem == "note" then
                                options.currentItem = "instrument"
                            elseif options.currentItem == "instrument" then
                                options.currentItem = "volume"
                            elseif options.currentItem == "volume" and options.currentChannel < 7 then
                                options.currentChannel = options.currentChannel + 1
                                options.currentItem = "note"
                            end
                            self:autoSetCursorPos()
                        elseif param == keys.backspace or param == keys.delete then
                            song:getFrameAt(options.currentFrame)[options.currentRow][options.currentChannel] = nil
                            stepRow()
                            self.needsRedraw = true
                        else
                            if options.currentItem == "note" then
                                pitch = noteKeys[keys.getName(param)]
                                if pitch ~= nil then
                                    local row = song:getFrameAt(options.currentFrame)[options.currentRow]
                                    local note = row[options.currentChannel]
                                    if note ~= nil then
                                        note[1] = pitch
                                    else
                                        row[options.currentChannel] = {pitch, options.currentInstrument, 15}
                                    end
                                    stepRow()
                                    playNotes({{row[options.currentChannel][1], row[options.currentChannel][2], 13}})
                                    self.needsRedraw = true
                                end
                            elseif options.currentItem == "instrument" and hexDigitSet[keys.getName(param)] then
                                local note = song:getFrameAt(options.currentFrame)[options.currentRow][options.currentChannel]
                                local instrumentNum = hex2dec(hexDigitMap[keys.getName(param)]) + 1
                                if note ~= nil then
                                    note[2] = instrumentNum
                                    options.currentInstrument = instrumentNum
                                    stepRow()
                                    panels.frames.needsRedraw = true
                                    self.needsRedraw = true
                                end
                            elseif options.currentItem == "volume" and hexDigitSet[keys.getName(param)] then
                                local note = song:getFrameAt(options.currentFrame)[options.currentRow][options.currentChannel]
                                if note ~= nil then
                                    note[3] = hex2dec(hexDigitMap[keys.getName(param)])
                                    stepRow()
                                    self.needsRedraw = true
                                end
                            end
                        end
                    end
                end
            end
        end
    }
    panels.frames = {
        window = window.create(term.current(), 46, 4, 5, 16),
        needsRedraw = true,
        gotoDefaultPosition = function(self)
            options.panel = "frames"
            self.window.setCursorPos(4, 9)
        end,
        redraw = function(self)
            self.window.clear()
            self.window.setCursorBlink(false)
            self.window.setCursorPos(1, 1)
            if not instruments[options.currentInstrument][4] then
                self.window.setTextColor(colors.red)
            end
            self.window.write(instruments[options.currentInstrument][3])
            self.window.setTextColor(colors.white)
            self.window.setCursorPos(1, 2)
            self.window.write("-----")
            for windowRow = 3, 16 do
                local dispFrame = windowRow - 9 + options.currentFrame
                if dispFrame >= 0 and dispFrame < options.frames then
                    self.window.setCursorPos(1, windowRow)
                    local colorString = "88044"
                    if dispFrame == options.currentFrame then
                        colorString = "00055"
                    end
                    self.window.blit(zeroPad(dec2hex(dispFrame), 2) .. " " .. zeroPad(dec2hex(song.order[dispFrame]), 2), colorString, "fffff")
                end
            end
            self.window.setCursorBlink(true)
        end,
        doAction = function(self, event, param)
            if options.shift == true then
                if event == "key" then
                    if param == keys.up then
                        panels.header:gotoDefaultPosition()
                    elseif param == keys.left then
                        panels.editor:gotoDefaultPosition()
                    end
                end
            else
                if event == "key" then
                    if param == keys.up then
                        if options.currentFrame == 0 then
                            options.currentFrame = options.frames - 1
                        else
                            options.currentFrame = options.currentFrame - 1
                        end
                        self.needsRedraw = true
                        panels.editor.needsRedraw = true
                    elseif param == keys.down then
                        if options.currentFrame == options.frames - 1 then
                            options.currentFrame = 0
                        else
                            options.currentFrame = options.currentFrame + 1
                        end
                        self.needsRedraw = true
                        panels.editor.needsRedraw = true
                    elseif param == keys.left and song.order[options.currentFrame] > 0 then
                        if isEmptyNestedTable(song.frames[song.order[options.currentFrame]]) then
                            song.frames[song.order[options.currentFrame]] = nil
                        end
                        song.order[options.currentFrame] = song.order[options.currentFrame] - 1
                        self.needsRedraw = true
                        panels.editor.needsRedraw = true
                    elseif param == keys.right and song.order[options.currentFrame] < 255 then
                        song.order[options.currentFrame] = song.order[options.currentFrame] + 1
                        if song.frames[song.order[options.currentFrame]] == nil then
                            song.frames[song.order[options.currentFrame]] = newFrame()
                        end
                        self.needsRedraw = true
                        panels.editor.needsRedraw = true
                    end
                end
            end
        end
    }
    panels.saveFile = {
        window = window.create(term.current(), 1, 1, 51, 19),
        needsRedraw = false,
        goBack = function(self)
            self.window.setVisible(false)
            self.window.clear()
            panels.header.window.setVisible(true)
            panels.editor.window.setVisible(true)
            panels.frames.window.setVisible(true)
            panels.header.needsRedraw = true
            panels.editor.needsRedraw = true
            panels.frames.needsRedraw = true
            panels.header:gotoDefaultPosition()
        end,
        gotoDefaultPosition = function(self)
            options.panel = "saveFile"
            panels.header.window.setVisible(false)
            panels.editor.window.setVisible(false)
            panels.frames.window.setVisible(false)
            self.window.setVisible(true)
            if isOkFilename(options.filename) then
                self.window.setCursorPos(17, 11)
            else
                self.window.setCursorPos(11, 9)
            end
            self.needsRedraw = true
        end,
        redraw = function(self)
            self.window.clear()
            self.window.setCursorBlink(false)
            self.window.setCursorPos(2, 9)
            self.window.write("Save as: " .. options.filename)
            self.window.setCursorPos(17, 11)
            local colorString = "5555"
            if(not isOkFilename(options.filename)) then
                colorString = "8888"
            end
            self.window.blit("SAVE", colorString, "ffff")
            self.window.setCursorPos(32, 11)
            self.window.blit("BACK", "3333", "ffff")
            self.window.setCursorBlink(true)
        end,
        doAction = function(self, event, param)
            local x, y = self.window.getCursorPos()
            if y == 9 then
                if event == "key" then
                    if param == keys.backspace then
                        local ok
                        options.filename, ok = deleteFromString(options.filename)
                        if ok then
                            self.window.setCursorPos(x - 1, y)
                            self.needsRedraw = true
                        end
                    elseif param == keys.down then
                        self.window.setCursorPos(17, 11)
                    end
                elseif event == "char" and x < 51 then
                    options.filename = options.filename .. param
                    self.window.setCursorPos(x + 1, y)
                    self.needsRedraw = true
                end
            else -- y = 11
                if x == 17 then -- SAVE
                    if event == "key" then
                        if (param == keys.enter or param == keys.space) and isOkFilename(options.filename) then
                            saveSong(options.filename)
                            self:goBack()
                        elseif param == keys.right then
                            self.window.setCursorPos(32, 11)
                        elseif param == keys.up then
                            self.window.setCursorPos(11 + string.len(options.filename), 9)
                        end
                    end
                else -- BACK
                    if event == "key" then
                        if param == keys.enter or param == keys.space then
                            self:goBack()
                        elseif param == keys.left then
                            self.window.setCursorPos(17, 11)
                        elseif param == keys.up then
                            self.window.setCursorPos(11 + string.len(options.filename), 9)
                        end
                    end
                end
            end
        end
    }
    panels.loadFile = {
        window = window.create(term.current(), 1, 1, 51, 19),
        needsRedraw = false,
        goBack = function(self)
            self.window.setVisible(false)
            self.window.clear()
            panels.header.window.setVisible(true)
            panels.editor.window.setVisible(true)
            panels.frames.window.setVisible(true)
            panels.header.needsRedraw = true
            panels.editor.needsRedraw = true
            panels.frames.needsRedraw = true
            panels.header:gotoDefaultPosition()
        end,
        gotoDefaultPosition = function(self)
            options.panel = "loadFile"
            self.errorMsg = nil
            panels.header.window.setVisible(false)
            panels.editor.window.setVisible(false)
            panels.frames.window.setVisible(false)
            self.window.setVisible(true)
            self.window.setCursorPos(13, 9)
            self.needsRedraw = true
        end,
        redraw = function(self)
            self.window.clear()
            self.window.setCursorBlink(false)
            if self.errorMsg ~= nil then
                self.window.setTextColor(colors.red)
                self.window.setCursorPos(3, 4)
                self.window.write("Error: " .. self.errorMsg)
                self.window.setTextColor(colors.white)
            end
            self.window.setCursorPos(2, 9)
            self.window.write("Load file: " .. options.tempFilename)
            self.window.setCursorPos(17, 11)
            local colorString = "5555"
            if(not isOkFilename(options.tempFilename) or not fileExists(options.tempFilename)) then
                colorString = "8888"
            end
            self.window.blit("LOAD", colorString, "ffff")
            self.window.setCursorPos(32, 11)
            self.window.blit("BACK", "3333", "ffff")
            self.window.setCursorBlink(true)
        end,
        doAction = function(self, event, param)
            local x, y = self.window.getCursorPos()
            if y == 9 then
                if event == "key" then
                    if param == keys.backspace then
                        local ok
                        options.tempFilename, ok = deleteFromString(options.tempFilename)
                        if ok then
                            self.window.setCursorPos(x - 1, y)
                            self.needsRedraw = true
                        end
                    elseif param == keys.down then
                        self.window.setCursorPos(17, 11)
                    end
                elseif event == "char" and x < 51 then
                    options.tempFilename = options.tempFilename .. param
                    self.window.setCursorPos(x + 1, y)
                    self.needsRedraw = true
                end
            else -- y = 11
                if x == 17 then -- LOAD
                    if event == "key" then
                        if (param == keys.enter or param == keys.space) and isOkFilename(options.tempFilename) and fileExists(options.tempFilename) then
                            result = loadSong(options.tempFilename)
                            if result ~= nil then
                                self.errorMsg = result
                                self.needsRedraw = true
                            else
                                options.filename = options.tempFilename
                                options.tempFilename = ""
                                self:goBack()
                            end
                        elseif param == keys.right then
                            self.window.setCursorPos(32, 11)
                        elseif param == keys.up then
                            self.window.setCursorPos(13 + string.len(options.tempFilename), 9)
                        end
                    end
                else -- BACK
                    if event == "key" then
                        if param == keys.enter or param == keys.space then
                            self:goBack()
                        elseif param == keys.left then
                            self.window.setCursorPos(17, 11)
                        elseif param == keys.up then
                            self.window.setCursorPos(13 + string.len(options.tempFilename), 9)
                        end
                    end
                end
            end
        end
    }

    -- check available instruments
    for i, instr in ipairs(instruments) do
        instr[4] = pcall(function() speaker.playNote(instr[1], 0, 0) end)
    end

    -- setup starting display
    panels.saveFile.window.setVisible(false)
    panels.loadFile.window.setVisible(false)

    term.clear()
    panels.header:gotoDefaultPosition()
end

init()
main()
term.clear()
term.setCursorPos(1, 1)