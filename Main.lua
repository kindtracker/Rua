local Rua = require("Rua.Rua")

local State = Rua.new()

local FileName = nil
local OutputFile = "a.ruac"
local ArgumentIndex = 1
while ArgumentIndex <= #arg do
  local Argument = arg[ArgumentIndex]

  if Argument == "--HiddenDevMode" then
    Rua._DevMode = true
  elseif Argument == "-o" then
    ArgumentIndex = ArgumentIndex + 1
    OutputFile = arg[ArgumentIndex]
  else
    FileName = Argument
  end

  ArgumentIndex = ArgumentIndex + 1
end

local Result, Error = Rua:Compile(State, FileName)
if not Result then
  return
end

local OutputPtr, OpenError = io.open(OutputFile, "wb")
OutputPtr:write(Result)
OutputPtr:close()
