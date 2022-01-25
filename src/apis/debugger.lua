local bit32 = require("bit32")
local ffi = require("ffi")
local SDL = elsa.SDL

local window
local windowID
local renderer
local texture, copytexture


local charCache={}
local char8 = ffi.new("uint32_t[?]", 8*16)
local char16 = ffi.new("uint32_t[?]", 16*16)
local function charWidth(ochar)
	return #font[ochar] / 4
end

local function _renderChar(ochar)
	char = font[ochar]
	local size,pchar = #char/16
	if size == 2 then
		pchar = char8
	else
		pchar = char16
	end
	local cy = 0
	for i = 1,#char,size do
		local line = tonumber(char:sub(i,i+size-1),16)
		local cx = 0
		for j = size*4-1,0,-1 do
			local bit = math.floor(line/2^j)%2
			pchar[cy*size*4+cx] = (bit == 0 and 0 or 0xFFFFFFFF)
			cx = cx + 1
		end
		cy = cy + 1
	end
	local texture = SDL.createTexture(renderer, SDL.PIXELFORMAT_ARGB8888, SDL.TEXTUREACCESS_STATIC, size*4, 16);
	SDL.setTextureBlendMode(texture, SDL.BLENDMODE_BLEND)
	SDL.updateTexture(texture, ffi.NULL, pchar, (size*4) * ffi.sizeof("uint32_t"))
	charCache[ochar] = texture
end

local function renderChar(char, x, y, r, g, b)
	if font[char] == nil then
		char = 63
	end
	if not charCache[char] then
		_renderChar(char)
	end
	local dest = ffi.new("SDL_Rect",{x=x,y=y,w=#font[char]/4,h=16})
	if char~=32 then
		SDL.setTextureColorMod(charCache[char], r, g, b)
		SDL.renderCopy(renderer, charCache[char], ffi.NULL, dest)
	end
end

-- graphics api
local g = {}

function g.setColor(red, green, blue)
	SDL.setRenderDrawColor(renderer, red, green, blue, SDL.ALPHA_OPAQUE)
	g.color = { red, green, blue }
end

function g.fillRect(x, y, w, h)
	local rect = ffi.new("SDL_Rect", { x = x, y = y, w = w, h = h })
	SDL.renderFillRect(renderer, rect)
end

function g.drawLine(x1, y1, x2, y2)
	SDL.renderDrawLine(renderer, x1, y1, x2, y2)
end

function g.drawText(x, y, text)
	for i=1, #text do
		local char = text:sub(i, i):byte()
		renderChar(char, x, y, table.unpack(g.color))
		x = x + charWidth(char)
	end
end

function g.getTextMetrics(text)
	local width = 0
	for i=1, #text do
		local char = text:sub(i, i):byte()
		width = width + charWidth(char)
	end

	return { width = width, height = 16 }
end

function g.clear()
	g.setCurrentY(0)
	SDL.renderFillRect(renderer, ffi.NULL)
end

function g.setCurrentY(y)
	g.y = y
end

function g.getCurrentY()
	return g.y
end

local function createWindow()
	if not window then
		window = SDL.createWindow("OCEmu - Debugger", 1, 1,
			800, 600, bit32.bor(SDL.WINDOW_SHOWN, SDL.WINDOW_ALLOW_HIGHDPI))
		if window == ffi.NULL then
			error(ffi.string(SDL.getError()))
		end
		windowID = SDL.getWindowID(window)

		-- Attempt to fix random issues on Windows 64bit
		SDL.setWindowFullscreen(window, 0)
		SDL.restoreWindow(window)
		SDL.setWindowSize(window, 800, 600)
		SDL.setWindowPosition(window, SDL.WINDOWPOS_CENTERED, SDL.WINDOWPOS_CENTERED)
		SDL.setWindowGrab(window, SDL.FALSE)
		--]]
	end
	renderer = SDL.createRenderer(window, -1, SDL.RENDERER_TARGETTEXTURE)
	if renderer == ffi.NULL then
		error(ffi.string(SDL.getError()))
	end
	SDL.setRenderDrawBlendMode(renderer, SDL.BLENDMODE_BLEND)
	texture = SDL.createTexture(renderer, SDL.PIXELFORMAT_ARGB8888, SDL.TEXTUREACCESS_TARGET, 800, 600);
	if texture == ffi.NULL then
		error(ffi.string(SDL.getError()))
	end
	copytexture = SDL.createTexture(renderer, SDL.PIXELFORMAT_ARGB8888, SDL.TEXTUREACCESS_TARGET, 800, 600);
	if copytexture == ffi.NULL then
		error(ffi.string(SDL.getError()))
	end

	-- Initialize all the textures to black
	SDL.setRenderDrawColor(renderer, 0, 0, 0, 255)
	SDL.renderFillRect(renderer, ffi.NULL)
	SDL.setRenderTarget(renderer, copytexture)
	SDL.renderFillRect(renderer, ffi.NULL)
	SDL.setRenderTarget(renderer, texture)
	SDL.renderFillRect(renderer, ffi.NULL)
end

local function cleanUpWindow(wind)
	SDL.destroyTexture(texture)
	SDL.destroyTexture(copytexture)
	SDL.destroyRenderer(renderer)
	if wind then
		SDL.destroyWindow(window)
		window, windowID = nil
	end
	texture, copytexture, renderer = nil
	os.exit() -- todo: gracefully shutdown
end

function elsa.windowclose(event)
	if event.windowID ~= windowID then
		return
	end
	cleanUpWindow(true)
end

local function drawProfiler(g)

end

debuggerTabs = {
	{ name = "Profiler", draw = drawProfiler }
}

local selectedTab = 2
local function drawTabs()
	local x = 0
	for k, tab in pairs(debuggerTabs) do
		if selectedTab == k then
			g.setColor(230, 230, 230)
		else
			g.setColor(200, 200, 200)
		end
		local metrics = g.getTextMetrics(tab.name)
		g.fillRect(x, g.y, metrics.width, metrics.height)
		g.setColor(0, 0, 0)
		g.drawText(x, g.y, tab.name)
		x = x + metrics.width + 16
	end
	g.y = g.y + 40

	debuggerTabs[selectedTab].draw(g)
end

local function drawUI()
	g.setColor(100, 100, 100)
	g.clear()
	drawTabs()
end

function elsa.draw()
	drawUI()

	SDL.setRenderTarget(renderer, ffi.NULL)
	SDL.renderCopy(renderer, texture, ffi.NULL, ffi.NULL)
	SDL.renderPresent(renderer)
	SDL.setRenderTarget(renderer, texture)
end

createWindow()
