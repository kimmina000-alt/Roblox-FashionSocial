--!strict
-- Shows the game in the player's own language (our translation tables, Shared/L.lua).
-- Korean players see nothing change. Studio test: set the attribute Lang ("en", "ja", ...)
-- on the LocalPlayer or on ReplicatedStorage.FashionGame, then rejoin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local L = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("L"))
L.start()
