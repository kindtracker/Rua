local Rua = require("Rua.Rua")
local CBackend = require("Rua.Backend.CBackend")

local State = Rua.new()

local FileName = nil
for ArgumentIndex, Argument in ipairs(arg) do
  if Argument == "_DevMode" then
    Rua._DevMode = true
  else
    FileName = Argument
  end
end

if FileName == nil then
  return
end

State:UseBackend(CBackend)

local Result, Error = Rua:Compile(State, FileName, FileName .. ".c")
