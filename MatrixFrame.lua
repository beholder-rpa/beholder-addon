local MatrixFrame = LibStub:NewLibrary("Beholder_MatrixFrame", 1);
MatrixFrame.frameId = 1;

local Settings = LibStub:GetLibrary("Beholder_Settings");
local Buffer = LibStub:GetLibrary("Beholder_Buffer");
local overlayFrame;

function MatrixFrame:RenderMatrix(matrixFrame, elapsedSinceLastRender, ...)
    if not elapsedSinceLastRender then
        elapsedSinceLastRender = 0
    end

    -- Don't render the frame if it's not shown - updating.
    if not matrixFrame:IsShown() then
        return false;
    end

    -- Don't render more than the defined value in settings.
    matrixFrame.elapsedSinceLastRender = matrixFrame.elapsedSinceLastRender + elapsedSinceLastRender;
    if (matrixFrame.elapsedSinceLastRender <= Settings.maxFPS) then
        return false;
    end
    
    -- Show the overlay frame if needed
    if (Buffer.showOverlay == true) then
        if not matrixFrame.overlayFrame:IsShown() then
            matrixFrame.overlayFrame:Show()
        end
    else
        if matrixFrame.overlayFrame:IsShown() then
            matrixFrame.overlayFrame:Hide()
        end
    end

    -- Don't render if the frame is not dirty.
    if Buffer.dirty == false then
        return false;
    end

    -- Prepare the buffer's contents
    Buffer:SerializeStack();
    
    -- Hide the matrix frame as we're painting
    matrixFrame:Hide()
    for y = 0, (matrixFrame.vPoints - 1) do
        for x = 0, (matrixFrame.hPoints - 1) do
            local currentText = matrixFrame.pointFrames[y][x];
            local value = Buffer:GetColorValueForPixel(x, y);
            if (value.r == nil) then value.r = 0 end
            if (value.g == nil) then value.g = 0 end
            if (value.b == nil) then value.b = 0 end
            currentText:SetTextColor(value.r, value.g, value.b, 1.0);
        end
    end
    -- Show it now we're done.
    matrixFrame:Show();

    Buffer:ClearBuffer(MatrixFrame.frameId);
    MatrixFrame.IncrementFrameId();
    
    matrixFrame.elapsedSinceLastRender = 0;
    return true
end

function MatrixFrame:IncrementFrameId()
    MatrixFrame.frameId = MatrixFrame.frameId + 1;
    if (MatrixFrame.frameId > (255 * 255 * 255)) then MatrixFrame = 1 end
end

function MatrixFrame:CreateMatrixFrame(parentFrame, hPoints, vPoints, overlayFrame)

    local matrixFrame = CreateFrame("Frame", nil, parentFrame);
    matrixFrame:ClearAllPoints()
    matrixFrame:SetSize(parentFrame:GetWidth(), parentFrame:GetHeight())
    matrixFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, 0)
    matrixFrame.parentFrame = parentFrame
    matrixFrame.hPoints = hPoints
    matrixFrame.vPoints = vPoints
    matrixFrame.pointFrames = {}
    matrixFrame.overlayFrame = overlayFrame
    matrixFrame.elapsedSinceLastRender = 0
    
    matrixFrame:SetScript("OnUpdate", function(self, elapsedSinceLastRender, ...)
        MatrixFrame:RenderMatrix(matrixFrame, elapsedSinceLastRender)
    end)

    local size = Settings.size;
    for y = 0, (matrixFrame.vPoints - 1) do
        matrixFrame.pointFrames[y] = {}

        for x = 0, (matrixFrame.hPoints - 1) do
            matrixFrame.pointFrames[y][x] = matrixFrame:CreateFontString(nil, "OVERLAY")

            local currentText = matrixFrame.pointFrames[y][x]
            currentText:ClearAllPoints()
            currentText:SetFont(parentFrame.font, size)
            currentText:SetText(Settings.character);
            currentText:SetPoint("TOPLEFT", matrixFrame, "TOPLEFT", x * size, -y * size)
            currentText:SetTextColor(0, 0, 0, 1.0);
        end
    end

    return matrixFrame
end