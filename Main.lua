local Rua = require("Rua.Rua")

local State = Rua.new()

local FileName = nil
for ArgumentIndex, Argument in ipairs(arg) do
  if Argument == "--HiddenDevMode" then
    Rua._DevMode = true
  else
    FileName = Argument
  end
end

if FileName == nil then
  return
end

local Result, Error = Rua:Compile(State, FileName, FileName .. ".c", {
  AddMain = true,
})
