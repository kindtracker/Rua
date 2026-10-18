local Rua = require("Rua")

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

-- Or State.ErrorMessage
local Result, Error = Rua:Run(State, FileName)
