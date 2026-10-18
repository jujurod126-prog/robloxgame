--!strict
--[[
	NumberFormat
	Display helpers for currency amounts.
	  NumberFormat.commas(12345)  -> "12,345"
	  NumberFormat.short(2500000) -> "2.5M"   (below 100,000 uses commas)
]]

local NumberFormat = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }

function NumberFormat.commas(value: number): string
	local whole = tostring(math.floor(math.abs(value)))
	local formatted = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return if value < 0 then "-" .. formatted else formatted
end

function NumberFormat.short(value: number): string
	local absolute = math.abs(value)
	if absolute < 100000 then
		return NumberFormat.commas(value)
	end
	local index = math.min(math.floor(math.log10(absolute) / 3), #SUFFIXES)
	local scaled = value / 10 ^ (index * 3)
	-- One decimal place, without a trailing ".0".
	local text = string.format("%.1f", math.floor(scaled * 10) / 10):gsub("%.0$", "")
	return text .. SUFFIXES[index]
end

return NumberFormat
