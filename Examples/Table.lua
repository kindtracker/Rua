local Empty = {}

local Numbers = { 10, 20, 30 }

local Player = {
  Name = "Rua",
  Health = 100,
  Level = 5,
}

local mixed = {
  "Hello",
  "World",
  Name = "Rua",
  [10] = "Ten",
}

local Game = {
  Player = {
    Name = "Knight",
    Health = 150,
  },
  Inventory = {
    "sword",
    "shield",
    "potion",
  },
}

local First = Numbers[1]
local PlayerName = PlayerName
local PlayerHealth = Game.player.Health
local FirstItem = Game.Inventory[1]

Numbers[2] = 99
Player.Health = 80
Game.Inventory[2] = "Bow"

local Config = true and {
  Debug = true,
  Version = 1,
} or {}

print({ X = 10, Y = 20 })

local Alias = Player
Alias.Level = 6

print(Player.Level)
