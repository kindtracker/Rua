local Rua = require("Rua")
local CBackend = require("CBackend")

local State = Rua.new()

local FileName = nil
for ArgumentIndex, Argument in ipairs(arg) do
  if Argument == "+DevMode" then
    Rua.DevMode = true
  else
    FileName = Argument
  end
end

if FileName == nil then
  return
end

State:UseBackend(CBackend)

local Result, Error = Rua:Compile(State, FileName, FileName .. ".c")
print(Result)
