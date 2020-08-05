local Settings = LibStub:NewLibrary("Beholder_Settings", 1)

if not Settings then return end

-- Configurable Variables
Settings.width = 156;
Settings.height = 46;

Settings.offsetX = 3;
Settings.offsetY = -673;

-- this is the size of the "pixels" that incidate current status
Settings.size = 2;

-- this is the path to the font that will be used. (If it's not picking up the font, try clearing cache..)
-- Use a mono-spaced font for consistency
Settings.fontPath = "Interface\\AddOns\\Beholder\\Fonts\\joystix.ttf"
Settings.character = "█"

-- this is the time, in seconds, that each "pixel" should be on screen for. E.g. 0.25 will no render a pixel more than 4x a second.
Settings.maxFPS= 0.10;