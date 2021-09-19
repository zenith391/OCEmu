local address, _, tier = ...

local ffi = require("ffi")
local desired = ffi.new("SDL_AudioSpec",{freq=8000, format=elsa.SDL.AUDIO_S16, channels=1, samples=4096, callback=ffi.NULL})
local obtained = ffi.new("SDL_AudioSpec",{})
local dev = elsa.SDL.openAudioDevice(ffi.NULL, 0, desired, obtained, 0)
if dev == 0 then
	print(elsa.getError())
else
	local same=true
	for k,v in pairs({"freq", "format", "channels"}) do
		if desired[v] ~= obtained[v] then
			same = false
			print(v .. ") " .. desired[v] .. " -> " .. obtained[v])
		end
	end
	if not same then
		print("Could not obtain requested audio format.")
	end
end

-- computronics sound card component
local mai = {}
local obj = {}
local delayTime = 0
local delayQueue = {}
local channels = {}
for i=1, 8 do
	channels[i] = {
		open = false,
		frequency = 0
	}
end
local di = {
	class = "multimedia",
	description = "Audio interface",
	vendor = "Yanaki Sound Systems",
	product = "MinoSound 244-X"
}

local function checkChannel(n, index)
	compCheckArg(n, index, "number")
	index = math.floor(index)
	if index < 1 or index > 8 then
		error("invalid channel: " .. tostring(index))
	end
	return index
end

mai.setAM = {direct = true, doc = "function(channel:number, modIndex:number); Instruction; Assigns an amplitude modulator channel to the specified channel."}
function obj.setAM(channel, modIndex)
	--STUB
	cprint("sound.setAM", channel, modIndex)
end

mai.resetAM = {direct = true, doc = "function(channel:number); Instruction; Removes the specified channel's amplitude modulator."}
function obj.resetAM(channel)
	--STUB
	cprint("sound.resetAM", channel)
end

mai.setFM = {direct = true, doc = "function(channel:number, modIndex:number, intensity:number); Instruction; Assigns a frequency modulator channel to the specified channel with the specified intensity."}
function obj.setFM(channel, modIndex, intensity)
	--STUB
	cprint("sound.setFM", channel, modIndex, intensity)
end

mai.resetFM = {direct = true, doc = "function(channel:number); Instruction; Removes the specified channel's frequency modulator."}
function obj.resetFM(channel)
	--STUB
	cprint("sound.resetFM", channel)
end

mai.setADSR = {direct = true, doc = "function(channel:number, attack:number, decay:number, attenuation:number, release:number); Instruction; Assigns ADSR to the specified channel with the specified phase durations in milliseconds and attenuation between 0 and 1."}
function obj.setADSR(channel, attack, decay, attenuation, release)
	--STUB
	cprint("sound.setADSR", channel, attack, decay, attenuation, release)
end

mai.setLFSR = {direct = true, doc = "function(channel:number, initial:number, mask:number); Instruction; Makes the specified channel generate LFSR noise. Functions like a wave type."}
function obj.setLFSR(channel, initial, mask)
	--STUB
	cprint("sound.setLFSR", channel, initial, mask)
end

mai.setTotalVolume = {direct = true, doc = "function(volume:number); Sets the general volume of the entire sound card to a value between 0 and 1. Not an instruction, this affects all channels directly."}
function obj.setTotalVolume(volume)
	--STUB
	cprint("sound.setTotalVolume", volume)
end

mai.setVolume = {direct = true, doc = "function(channel:number, volume:number); Instruction; Sets the volume of the channel between 0 and 1."}
function obj.setVolume(channel, volume)
	--STUB
	cprint("sound.setVolume", channel, volume)
end

mai.resetEnvelope = {direct = true, doc = "function(channel:number); Instruction; Removes ADSR from the specified channel."}
function obj.resetEnvelope(channel)
	--STUB
	cprint("sound.resetEnvelope", channel)
end

mai.close = {direct = true, doc = "function(channel:number); Instruction; Closes the specified channel, stopping sound from being generated."}
function obj.close(channel)
	cprint("sound.close", channel)
	channels[checkChannel(1, channel)].open = false
end

mai.setWave = {direct = true, doc = "function(channel:number, type:number); Instruction; Sets the wave type on the specified channel."}
function obj.setWave(channel, type)
	--STUB
	cprint("sound.setWave", channel, type)
end

mai.open = {direct = true, doc = "function(channel:number); Instruction; Opens the specified channel, allowing sound to be generated."}
function obj.open(channel)
	cprint("sound.open", channel)
	channels[checkChannel(1, channel)].open = true
end

mai.clear = {direct = true, doc = "function(); Clears the instruction queue."}
function obj.clear()
	cprint("sound.clear")
	delayTime = 0
	delayQueue = {}
end

mai.modes = {doc = "This is a bidirectional table of all valid modes."}
function obj.modes()
	--STUB
	cprint("sound.modes")
end

local processEnd = 0
local processTime = 0
local processQueue = {}
mai.process = {direct = true, doc = "function(); Starts processing the queue; Returns true is processing began, false if there is still a queue being processed."}
function obj.process()
	--STUB
	cprint("sound.process")
	elsa.SDL.pauseAudioDevice(dev, 0)
			print(elsa.SDL.getQueuedAudioSize(dev))

	if processEnd == 0 then
		-- start process
		processEnd = elsa.timer.getTime() * 1000 + delayTime
		processTime = delayTime
		processQueue = delayQueue -- cloned
		delayQueue = {}
		delayTime = 0
		print("start processing!")
		return true
	else
		return false
	end
end

mai.channel_count = {doc = "This is the number of channels this card provides.", getter = true }
function obj.channel_count()
	cprint("sound.channel_count")
	return 8
end

mai.delay = {direct = true, doc = "function(duration:number); Instruction; Adds a delay of the specified duration in milliseconds, allowing sound to generate."}
function obj.delay(duration)
	cprint("sound.delay", duration)
	local delayEntry = {}
	for _, channel in pairs(channels) do
		if channel.open and channel.frequency ~= 0 then
			table.insert(delayEntry, {
				frequency = channel.frequency,
				offset = 0
			})
		end
	end
	table.insert(delayQueue, { tstart = delayTime, tend = delayTime + duration, entry = delayEntry })

	delayTime = delayTime + duration
end

mai.setFrequency = {direct = true, doc = "function(channel:number, frequency:number); Instruction; Sets the frequency on the specified channel."}
function obj.setFrequency(channel, frequency)
	cprint("sound.setFrequency", channel, frequency)
	channel = checkChannel(1, channel)
	compCheckArg(2, frequency, "number")

	channels[channel].frequency = frequency
end

local firstProc = false
table.insert(machineTickHandlers, function(dt)
	if processEnd ~= 0 then
		local timeMs = elsa.timer.getTime() * 1000
		if timeMs >= processEnd-- and elsa.SDL.getQueuedAudioSize(dev) == 0 then
			then
			processEnd = 0
			processQueue = {}
			firstProc = true
			return
		end
		if firstProc then
			local datatype = ffi.typeof("int16_t[?]")
			local rate = tonumber(obtained.freq)
			local vol = 32*255
			local offset = 0
			local duration = processTime

			local time = 0
			local sampleCount = math.floor(duration*rate/1000)
			local data = datatype(sampleCount)
			for i=1, sampleCount do
				local value = 0
				for _, item in pairs(processQueue) do
					if time*1000 >= item.tstart and time*1000 < item.tend then
						local entry = item.entry
						for k, channel in pairs(entry) do
							local step = channel.frequency / rate

							local remainder = (time*channel.frequency) % 1
							if remainder > 0.5 then
								value = value + vol
							else
								value = value - vol
							end
						end
					end
				end
				data[i-1] = value
				time = time + (1 / rate)
			end
			if elsa.SDL.queueAudio(dev, data, sampleCount * 2) ~= 0 then
				error(elsa.getError())
			end
			print(elsa.SDL.getQueuedAudioSize(dev))
			firstProc = false
		end
	end
end)

obj.type = "sound"
return obj,nil,mai,di
