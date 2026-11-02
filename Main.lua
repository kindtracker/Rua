local Rua = require("Rua.Rua")
local CBackend = require("Rua.CBackend.CBackend")

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

CBackend:UseRuaRuntime(State, "Rua/CBackend/RuaRuntime.c")
State:UseBackend(CBackend)

local Result, Error = Rua:Compile(State, FileName, FileName .. ".c", {
  AddMain = true,
})
