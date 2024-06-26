local env = ...

local function tlen(t)
	local n = -math.huge
	for k in pairs(t) do
		if type(k) == "number" and k >= n then
			n = k
		end
	end
	return n
end

local proxylist = {}
local slotlist = {}
local emuicc = {}
local mailist = {}
local dilist = {}

component = {}

function component.connect(info, ...)
	local address
	if type(info) ~= "table" then
		info = table.pack(info, ...)
	else
		info.n = tlen(info)
	end
	checkArg(2,info[2],"string","number")
	if type(info[2]) == "string" then
		address = info[2]
	else
		address = gen_uuid()
	end
	if proxylist[address] ~= nil then
		return nil, "component already at address"
	end
	info[2] = address
	local fn, err = elsa.filesystem.load("component/" .. info[1] .. ".lua")
	if not fn then
		return nil, err
	end
	local proxy, cec, mai, di = fn(table.unpack(info, 2, info.n))
	if not proxy then
		return nil, cec or "no component added"
	end
	for k, v in pairs(proxy) do
		if type(v) == "function" then
			if mai[k] == nil then mai[k] = {} end
			if mai[k].direct == nil then mai[k].direct = false end
			if mai[k].limit == nil then mai[k].limit = math.huge end
			if mai[k].doc == nil then mai[k].doc = "" end
			if mai[k].getter == nil then mai[k].getter = false end
			if mai[k].setter == nil then mai[k].setter = false end
		end
	end
	proxy.address = address
	proxy.type = proxy.type or info[1]
	proxylist[address] = proxy
	emuicc[address] = cec
	mailist[address] = mai
	dilist[address] = di
	slotlist[address] = info[3]
	if boot_machine then
		table.insert(machine.signals,{"component_added",address,proxy.type})
	end
	return true
end
function component.disconnect(address)
	checkArg(1,address,"string")
	if proxylist[address] == nil then
		return nil, "no component at address"
	end
	local thetype = proxylist[address].type
	proxylist[address] = nil
	emuicc[address] = nil
	mailist[address] = nil
	dilist[address] = nil
	slotlist[address] = nil
	table.insert(machine.signals,{"component_removed",address,thetype})
	return true
end
function component.deviceInfo(address)
	return dilist[address]
end
function component.exists(address)
	checkArg(1,address,"string")
	if proxylist[address] ~= nil then
		return proxylist[address].type
	end
end
function component.list(filter, exact)
	checkArg(1,filter,"string","nil")
	local data = {}
	local tbl = {}
	for k,v in pairs(proxylist) do
		if filter == nil or (exact and v.type == filter) or (not exact and v.type:find(filter, nil, true)) then
			data[#data + 1] = k
			data[#data + 1] = v.type
			tbl[k] = v.type
		end
	end
	local place = 1
	return setmetatable(tbl,{__call = function()
		local addr,type = data[place], data[place + 1]
		place = place + 2
		return addr,type
	end})
end
function component.invoke(address, method, ...)
	checkArg(1,address,"string")
	checkArg(2,method,"string")
	if proxylist[address] ~= nil then
		if proxylist[address][method] == nil then
			error("no such method",2)
		end
		return proxylist[address][method](...)
	end
end
function component.cecinvoke(address, method, ...)
	checkArg(1,address,"string")
	checkArg(2,method,"string")
	if emuicc[address] ~= nil then
		if emuicc[address][method] == nil then
			error("no such method",2)
		end
		return emuicc[address][method](...)
	end
end

-- Load components
local components = settings.components
for k,v in pairs(components) do
	v[2] = v[2] or k
	local ok, err=component.connect(v)
	if not ok then
		error(err,0)
	end
end

env.component = setmetatable({list = component.list},{
	__index = function(_,k)
		cprint("Missing environment access", "env.component." .. k)
	end,
})

function env.component.type(address)
	checkArg(1,address,"string")
	if proxylist[address] ~= nil then
		return proxylist[address].type
	end
	return nil, "no such component"
end

function env.component.slot(address)
	checkArg(1,address,"string")
	if proxylist[address] ~= nil then
		return slotlist[address]
	end
	return nil, "no such component"
end

function env.component.methods(address)
	checkArg(1,address,"string")
	if proxylist[address] ~= nil then
		local methods = {}
		for k,v in pairs(proxylist[address]) do
			if type(v) == "function" then
				local methodmai = mailist[address][k]
				methods[k] = {direct=(settings.fast or methodmai.direct), getter=methodmai.getter, setter=methodmai.setter}
			end
		end
		return methods
	end
	return nil, "no such component"
end

function env.component.invoke(address, method, ...)
	checkArg(1,address,"string")
	checkArg(2,method,"string")
	if proxylist[address] ~= nil then
		if proxylist[address][method] == nil then
			error("no such method",2)
		end
		if mailist[address][method].direct and not machine.consumeCallBudget(1/mailist[address][method].limit) then
			return
		end
		local results = table.pack(pcall(proxylist[address][method], ...))
		if machine.callBudget < 0 then
			return
		end
		return table.unpack(results, 1, results.n)
	end
	return nil, "no such component"
end

function env.component.doc(address, method)
	checkArg(1,address,"string")
	checkArg(2,method,"string")
	if proxylist[address] ~= nil then
		if proxylist[address][method] == nil then
			return nil
		end
		if mailist[address] ~= nil then
			return mailist[address][method].doc
		end
		return nil
	end
	return nil, "no such component"
end
