-- Represents the circular buffer data structure that the on-screen pixel matrix will be populated with.
local Buffer = LibStub:NewLibrary("Beholder_Buffer", 1)

if not Buffer then return end

local Settings = LibStub:GetLibrary("Beholder_Settings");
local Util = LibStub:GetLibrary("Beholder_Util");
local json = LibStub:GetLibrary("json")
local fmod = math.fmod;
local byte = string.byte;

Buffer.frameType = 0;
Buffer.stack = {};
Buffer.stackPosition = 1;
Buffer.lastFrameId = 0;
Buffer.showOverlay = false;

function Buffer:ClearBuffer(frameId, force)
    if not force and Buffer.frameType ~= 0 then
        return
    end

    for i=1, Settings.width * Settings.height * 3 do
        Buffer[i] = nil;
    end
    -- Add the frame id (little-endian)
    Buffer:WriteFrameMetadata(frameId);

    Buffer.position = 7;
    Buffer.dirty = false;
    Buffer.showOverlay = false;
    Buffer.frameType = 0;
    Buffer.stack = {};
    Buffer.stackPosition = 1;
end

function Buffer:WriteFrameMetadata(frameId)
    if not frameId then frameId = Buffer.lastFrameId + 1 end

    Buffer[1] = fmod(frameId, 255)
    Buffer[2] = fmod(floor(frameId / 255), 255)
    Buffer[3] = fmod(floor(frameId / (255 * 255)), 255)

    -- Add frame metadata
    Buffer[4] = Settings.width
    Buffer[5] = Settings.height
    
    Buffer[6] = ((Buffer.frameType % 16) * 16) + (Settings.size % 16)

    Buffer.lastFrameId = frameId;
end

function Buffer:ShowMatrixTestPattern()
    for ix = 0, (Settings.width * Settings.height) - 1 do
        local y = floor(ix / Settings.width) + 1;
        local x = fmod(ix, Settings.width) + 1;
        Buffer[ix*3+1] = x;
        Buffer[ix*3+2] = y;
        Buffer[ix*3+3] = 255;
    end

    Buffer.frameType = 1;
    Buffer:WriteFrameMetadata();
    Buffer.position = Settings.width * Settings.height * 3 + 1
    Buffer.dirty = true;
end

function Buffer:ShowAlphaNumericTestPattern()
    local pattern = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
    for ix = 1, Settings.width * Settings.height * 3 do
        local pos = fmod(ix - 6, strlen(pattern));
        if pos == 0 then pos = strlen(pattern) end
        local c = strsub(pattern, pos)
        Buffer[ix] = strbyte(c);
    end
    Buffer.frameType = 2;
    Buffer:WriteFrameMetadata();
    Buffer.position = Settings.width * Settings.height * 3 + 1
    Buffer.dirty = true;
end

function Buffer:ShowAlignmentPattern()
    for ix = 0, (Settings.width * Settings.height) - 1 do
        local y = floor(ix / Settings.width) + 1;
        local x = fmod(ix, Settings.width) + 1;
        Buffer[ix*3+1] = 0;
        Buffer[ix*3+2] = 255;
        Buffer[ix*3+3] = 0;
    end

    Buffer.frameType = 3;
    Buffer.position = Settings.width * Settings.height * 3 + 1
    Buffer.dirty = true;
    Buffer.showOverlay = true;
end

function Buffer:SerializeStack()
    if (Buffer.stackPosition <= 0) then
        return
    end
    local data = "["
    for ix = 1, Buffer.stackPosition - 1 do
        local item = json.encode(Buffer.stack[ix]);
        data = data .. item;
        if (ix + 1 < Buffer.stackPosition) then
            data = data .. ",";
        end
    end
    data = data .. "]";
    
    local length = strlen(data)
    if (length > Settings.width * Settings.height * 3) then
        print("serialized stack exceeds allowable length of a single frame - aborting.")
        return;
    end
    
    -- Write the actual data.
    for i = 1, length do
        local c = strsub(data, i, i)
        Buffer[Buffer.position] = byte(c);
        Buffer.position = Buffer.position + 1;
    end
end

function Buffer:GetColorValueForPixel(x, y)
    local result = {}
    local ix = (((y * Settings.width) + x) * 3) + 1
    result.r = Buffer[ix]
    result.g = Buffer[ix + 1]
    result.b = Buffer[ix + 2]

    if (result.r ~= nil) then
        result.r = fmod(result.r, 256) / 255;
    end

    if (result.g ~= nil) then
        result.g = fmod(result.g, 256) / 255;
    end

    if (result.b ~= nil) then
        result.b = fmod(result.b, 256) / 255;
    end
    
    return result;
end

function Buffer:SendMessage(data)
    if Buffer.frameType ~= 0 then
        return
    end
    
    Buffer.stack[Buffer.stackPosition] = data;
    Buffer.stackPosition = Buffer.stackPosition + 1;
    
    Buffer.dirty = true;
    Buffer.frameType = 0;
end
