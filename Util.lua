local Util = LibStub:NewLibrary("Beholder_Util", 1)

if not Util then return end

function Util:str2rgb(str)
    local result = {}
    str = tostring(str)
    for i = 0, strlen(str), 3 do
        result.r = strbyte(str, i)
        result.g = strbyte(str, i+1)
        result.b = strbyte(str, i+2)
    end
    return result
end

function Util:round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function Util:roundUp(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.ceil(num * mult) / mult
end

function Util:randomRGB()
    return Util:round(random(), 3);
end

-- Repeating Timer Management
do
	local frame = CreateFrame("Frame")
	local timers = {}
	local function SetDuration(self, duration)
		self.animation:SetDuration(duration)
	end
	-- Util:CreateTimer(func, duration, play)
	-- play=true|nil => timer running; play=false => timer paused
	-- timer methods: timer:Play() timer:Stop() timer:SetDuration()
	function Util:CreateTimer( func, duration, play )
		local timer = tremove(timers)
		if not timer then
			timer = frame:CreateAnimationGroup()
			timer.animation = timer:CreateAnimation()
			timer.SetDuration = SetDuration
			timer:SetLooping("REPEAT")
		end
		timer:SetScript("OnLoop", func)
		if duration then
			timer:SetDuration(duration)
			if play~=false then timer:Play() end
		end
		return timer
	end
	-- Util:CancelTimer(timer)
	function Util:CancelTimer( timer )
		if timer then
			timer:Stop()
			timers[#timers+1] = timer
		end
	end
end