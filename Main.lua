local Rua = require("Rua")
local VmDebugger = require("VmDebugger")

local State = Rua.new()

local FileName = nil
for ArgumentIndex, Argument in ipairs(arg) do
  if Argument == "+DevMode" then
    Rua.DevMode = true
  elseif Argument == "+VmDebugger" then
    VmDebugger:Initialize(State, Rua)
    VmDebugger:AddBreakpoint(State, 1)
  else
    FileName = Argument
  end
end

if FileName == nil then
  return
end

State.ExitOnError = true

-- Or State.ErrorMessage
local Result, Error = Rua:Run(State, FileName)
