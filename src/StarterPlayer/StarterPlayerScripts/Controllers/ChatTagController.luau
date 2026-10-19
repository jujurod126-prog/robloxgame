--!strict
--[[
	ChatTagController
	Adds a gold [VIP] tag in chat for players who own the VIP Truck pass
	(Player attribute "VIP", set by MarketService). Needs TextChatService chat.
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local VIP_TAG = `<font color="#FFC83C">[VIP]</font> `

local ChatTagController = {}

function ChatTagController.Init() end

function ChatTagController.Start()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
		local source = message.TextSource
		local sender = source and Players:GetPlayerByUserId(source.UserId)
		if sender and sender:GetAttribute("VIP") then
			local properties = Instance.new("TextChatMessageProperties")
			properties.PrefixText = VIP_TAG .. message.PrefixText
			return properties
		end
		return nil
	end
end

return ChatTagController
