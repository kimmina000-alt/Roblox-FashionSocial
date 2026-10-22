--!strict
-- Cafe part-time job (알바, CAFE.md §9, D-099). Every cafe that uses the
-- shared order system (SnackConfig.Shops, drinks only) can be worked at.
--
-- Loop: start work at the counter → orders come in (players ordering while a
-- staff member is on duty, plus NPC customers sitting at the tables) → make
-- the drink at the counter → bring it to the customer → clear the empty cup
-- left on the table. The server checks every step and pays the coins.
-- Rewards are the user's draft (CAFE.md §9); change them here only.

local CafeJobConfig = {}

-- cafes with a job (SnackConfig shop keys)
CafeJobConfig.Shops = { "BeachCafe", "HanokCafe" }

CafeJobConfig.ServeCoins = 4
CafeJobConfig.CleanCoins = 2
CafeJobConfig.DailyCap = 60 -- serving + cleaning, per player per day (UTC)

CafeJobConfig.MakeSeconds = 2.5 -- making a drink at the counter
CafeJobConfig.CounterDistance = 14 -- make drinks / start work this close to the counter
CafeJobConfig.ServeDistance = 9 -- hand the drink over this close to the customer
CafeJobConfig.WorkArea = 60 -- work ends when the staff walks this far from the counter

-- NPC customers (only while someone works at that cafe; PERFORMANCE.md: few)
CafeJobConfig.NpcMax = 3
CafeJobConfig.NpcEverySeconds = 18
CafeJobConfig.NpcStaySeconds = 20 -- drinking after being served, then leaves

-- orders
CafeJobConfig.OrderTimeout = 150 -- a player customer then gets the drink anyway; an NPC leaves
CafeJobConfig.PlayerOrderGap = 45 -- one player can order at a staffed cafe this often
CafeJobConfig.SamePairGap = 120 -- coins for serving the same player customer again only after this
CafeJobConfig.CupSeconds = 240 -- an empty cup nobody clears disappears after this

return CafeJobConfig
