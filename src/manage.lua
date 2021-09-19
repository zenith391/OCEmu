local ffi = require("ffi")
local lfs = require("lfs")

local args = elsa.args
local opts = elsa.opts
table.remove(args, 1)

if #args < 1 then
	print("Usage:")
	print("  manage [filesystem]")
	return
end

local function parseSize(size)
	if not size then return nil end
	local prefixes = {
		"KB", "MB", "GB", "TB"
	}
	for i, prefix in pairs(prefixes) do
		if size:sub(-#prefix):upper() == prefix then
			local number = size:sub(1, -#prefix - 1)
			local log = 1024^i
			return math.floor(number * log)
		end
	end
	error("invalid size")
end

config.load()
elsa.filesystem.load("apis/uuid.lua")(env)

if args[1] == "filesystem" then
	if #args < 2 then
		print("Usage:")
		print("  manage filesystem create [uuid]")
		print("    --label=... Set filesystem label")
		print("    --size=...  Set filesystem size")
		return
	end
	local components = config.get("emulator.components")

	if args[2] == "create" then
		local uuid = args[3] or gen_uuid()
		local label = opts.label or nil
		local size = parseSize(opts.size) or nil
		table.insert(components, {
			"filesystem", uuid, 5, nil, label, false, 4, size
		})
		print("Created empty filesystem with following metadata:")
		print("  UUID: " .. uuid)
		if label then
			print("  Label: " .. label)
		else
			print("  No label")
		end
		if size then
			print("  Size: " .. opts.size)
		else
			print("  Infinite size")
		end
		config.set("emulator.components", components)
		config.save()

		elsa.filesystem.createDirectory(elsa.filesystem.getSaveDirectory() .. "/" .. uuid)
	end
end
