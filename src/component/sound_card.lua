local address, _, tier = ...

local ffi = require("ffi")
local desired = ffi.new("SDL_AudioSpec",{freq=44100, format=elsa.SDL.AUDIO_S16, channels=1, samples=2048, callback=ffi.NULL})
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
		frequency = 0,
		volume = 1,
		adsrStartSet = false,
		waveType = 1, -- square wave
		adsr = {
			attack = 0,
			decay = 0,
			sustain = 1.0,
			release = 0
		}
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
		error("invalid channel: " .. tostring(index), 2)
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
function obj.setADSR(channel, attack, decay, sustain, release)
	cprint("sound.setADSR", channel, attack, decay, sustain, release)
	channels[checkChannel(1, channel)].adsr = {
		attack = attack  ,
		decay = decay,
		sustain = sustain,
		release = release
	}
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
	cprint("sound.setVolume", channel, volume)
	compCheckArg(2, volume, "number")
	if volume < 0 or volume > 1 then
		error("invalid volume: " .. tostring(volume), 2)
	end
	channels[checkChannel(1, channel)].volume = volume
end

mai.resetEnvelope = {direct = true, doc = "function(channel:number); Instruction; Removes ADSR from the specified channel."}
function obj.resetEnvelope(channel)
	cprint("sound.resetEnvelope", channel)
	channels[checkChannel(1, channel)].adsr = {
		attack = 0,
		decay = 0,
		sustain = 1.0,
		release = 0
	}
end

mai.close = {direct = true, doc = "function(channel:number); Instruction; Closes the specified channel, stopping sound from being generated."}
function obj.close(channel)
	cprint("sound.close", channel)
	channels[checkChannel(1, channel)].open = false
end

mai.setWave = {direct = true, doc = "function(channel:number, type:number); Instruction; Sets the wave type on the specified channel."}
function obj.setWave(channel, type)
	cprint("sound.setWave", channel, type)
	compCheckArg(2, type, "number")
	type = math.floor(type)
	if type >= 1 and type <= 4 or type == -1 then
		channels[checkChannel(1, channel)].waveType = type
	end
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

mai.modes = {doc = "This is a bidirectional table of all valid modes.", getter = true}
function obj.modes()
	cprint("sound.modes")
	return {
		["noise"] = -1,
		["square"] = 1,
		["sine"] = 2,
		["triangle"] = 3,
		["sawtooth"] = 4,
		[-1] = "noise",
		[1] = "square",
		[2] = "sine",
		[3] = "triangle",
		[4] = "sawtooth"
	}
end

local processEnd = 0
local processTime = 0
local processQueue = {}
local firstProc = true

local waveFunctions = {
	[1] = function(pos) -- square wave
		if pos > 0.5 then
			return 0.5
		else
			return -0.5
		end
	end,
	[2] = function(pos) -- sine wave
		return math.sin(2*math.pi*pos)
	end,
	[3] = function(pos) -- triangle wave
		return 1 - (math.abs(pos - 0.5) * 4.0)
	end,
	[4] = function(pos) -- sawtooth wave
		return (2 * pos) - 1
	end
}

local function produceSound()
	if processEnd ~= 0 then
		local timeMs = elsa.timer.getTime() * 1000
		if timeMs >= processEnd-- and elsa.SDL.getQueuedAudioSize(dev) == 0 then
			then
			processEnd = 0
			--processQueue = {}
			firstProc = true
			return
		end
		if firstProc then
			local datatype = ffi.typeof("int16_t[?]")
			local rate = tonumber(obtained.freq)
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
							local waveFunction = waveFunctions[channel.waveType]
							local step = channel.frequency / rate
							local remainder = (time*channel.frequency) % 1
							local attack = math.max(0, math.min(1, (time*1000 - channel.adsr.start) / channel.adsr.attack))
							local decayStart = channel.adsr.start + channel.adsr.attack
							local decay = math.min(1, math.max(channel.adsr.sustain, 1 - ((time*1000 - decayStart) / channel.adsr.decay)))
							local vol = (32000 / 8 * attack * decay) * channel.volume
							
							value = value + waveFunction(remainder) * vol
						end
					end
				end
				if value > 32000 then value = 32000 end
				if value < -32000 then value = -32000 end
				data[i-1] = math.floor(value)
				time = time + (1 / rate)
			end
			if elsa.SDL.queueAudio(dev, data, sampleCount * 2) ~= 0 then
				error(elsa.getError())
			end
			firstProc = false
		end
	end
end

mai.process = {direct = true, doc = "function(); Starts processing the queue; Returns true is processing began, false if there is still a queue being processed."}
function obj.process()
	cprint("sound.process")
	elsa.SDL.pauseAudioDevice(dev, 0)
	--print(elsa.SDL.getQueuedAudioSize(dev))

	if processEnd == 0 then
		-- start process
		processEnd = elsa.timer.getTime() * 1000 + delayTime
		processTime = delayTime
		processQueue = delayQueue -- cloned
		delayQueue = {}
		delayTime = 0
		for _, channel in pairs(channels) do
			if not channel.adsrStart then channel.adsrStart = 0 end
			channel.adsrStart = channel.adsrStart - processTime
		end
		produceSound()
		return true
	else
		return false
	end
end

mai.channel_count = {doc = "This is the number of channels this card provides.", getter = true}
function obj.channel_count()
	cprint("sound.channel_count")
	return 8
end

mai.delay = {direct = true, doc = "function(duration:number); Instruction; Adds a delay of the specified duration in milliseconds, allowing sound to generate."}
function obj.delay(duration)
	cprint("sound.delay", duration)
	if duration < 0 or duration > 8000 then
		error("invalid duration: " .. tostring(duration), 2)
	end
	local delayEntry = {}
	for k, channel in pairs(channels) do
		if channel.open and channel.frequency ~= 0 then
			if not channel.adsrStartSet or not channel.adsrStart then
				channel.adsrStart = delayTime
				channel.adsrStartSet = true
			end
			table.insert(delayEntry, {
				frequency = channel.frequency,
				volume = channel.volume,
				waveType = channel.waveType,
				id = k,
				offset = 0,
				adsr = {
					attack = channel.adsr.attack,
					decay = channel.adsr.decay,
					sustain = channel.adsr.sustain,
					start = channel.adsrStart
				}
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
	channels[channel].adsrStart = delayTime
	channels[channel].adsrStartSet = true
end

table.insert(machineTickHandlers, produceSound)

-- Debugger tab
if debuggerTabs then
	table.insert(debuggerTabs, {
		name = "Sound Card",
		draw = function(g)
			local channelHeight = 60
			local start = processEnd - processTime
			local time = math.floor(elsa.timer.getTime() * 1000 - start)
			if processEnd ~= 0 then
				g.setColor(0, 0, 0)
				g.drawText(0, 20, "Time (relative to buffer): " .. time .. " ms")
			end
			for i=1, 8 do
				g.setColor(0, 0, 0)
				g.drawText(0, g.y + 22, "Channel " .. i)
				g.setColor(200, 200, 200)

				if processEnd == 0 or not channels[i].open then -- not yet processing
					g.drawLine(150, g.y + 60, 700, g.y + 60)
					g.setColor(0, 0, 0)
					g.drawText(0, g.y + 22 + 16, "(closed)")
				else
					local unused = true
					for _, item in pairs(processQueue) do
						if time >= item.tstart and time < item.tend then
							local entry = item.entry
							for k, channel in pairs(entry) do
								if channel.id == i then
									g.setColor(0, 0, 0)
									g.drawText(0, g.y + 22 + 16, "Frequency: " .. channel.frequency .. "Hz")

									local timeFrame = 0.1 -- in seconds
									local waveTime = 0
									local points = {}
									local up = false
									local attack = math.max(0, math.min(1, (time - channel.adsr.start) / channel.adsr.attack))
									local decayStart = channel.adsr.start + channel.adsr.attack
									local decay = math.min(1, math.max(channel.adsr.sustain, 1 - ((time - decayStart) / channel.adsr.decay)))
									local vol = 60 * attack * decay
									g.drawText(0, g.y + 22 + 16 + 16, "Volume: " .. math.floor((vol/60)*100) ..
										"% * " .. math.floor(channel.volume*100) .. "%")

									while waveTime < timeFrame * 1.1 do
										if channel.waveType == 4 then -- sawtooth wave
											table.insert(points, {
												x = 150 + math.min(550, math.floor(waveTime * 550 / timeFrame)),
												y = math.floor(g.y + 60)
											})
											table.insert(points, {
												x = 150 + math.min(550, math.floor((waveTime+(2/channel.frequency)) * 550 / timeFrame)),
												y = math.floor(g.y + 60 - vol)
											})
										else
											if channel.waveType ~= 3 then -- triangle wave
												table.insert(points, {
													x = 150 + math.min(550, math.floor(waveTime * 550 / timeFrame)),
													y = math.floor(up and (g.y + 60) or (g.y + 60 - vol))
												})
											end
											table.insert(points, {
												x = 150 + math.min(550, math.floor(waveTime * 550 / timeFrame)),
												y = math.floor(up and (g.y + 60 - vol) or (g.y + 60))
											})
										end
										waveTime = waveTime + (((channel.waveType == 4) and 2 or 1) / channel.frequency)
										up = not up
									end

									local i = 2
									g.setColor(200, 200, 200)
									while i < #points do
										local prev = points[i-1]
										local cur  = points[i  ]
										g.drawLine(prev.x, prev.y, cur.x, cur.y)
										i = i + 1
									end
									unused = false
								end
							end
						end
					end
					if unused then
						g.drawLine(150, g.y + 60, 700, g.y + 60)
						g.setColor(0, 0, 0)
						g.drawText(0, g.y + 22 + 16, "Frequency: 0Hz")
						g.drawText(0, g.y + 22 + 32, "Volume: 0%")
					end
				end
				g.y = g.y + channelHeight + 10
			end
		end
	})
end

obj.type = "sound"
return obj,nil,mai,di
