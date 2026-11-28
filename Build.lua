local CFiles = {
  "Rua/Vm/Vm.h",
  "Rua/Vm/Vm.c",
  "Rua/Vm/Main.c",
}

local function EscapeString(String)
  return "'" .. String:gsub("'", "'\\''") .. "'"
end

local ResultCFile = ""

local BashFileFormat = [[
#!/usr/bin/env sh
VmSourceCode=%s

printf '%%s' "$VmSourceCode" > /tmp/rua_vm.c

CCompiler=$(command -v gcc || command -v clang || command -v g++ || command -v cc)
if [ -z "$CCompiler" ]; then
  echo "No C compiler found"
  exit 1
fi

$CCompiler -Wno-pragma-once-outside-header /tmp/rua_vm.c -o /tmp/rua_vm
/tmp/rua_vm
]]

local BytecodePtr = assert(io.open("Build/Program.ruac", "rb"))
local Bytecode = BytecodePtr:read("*a")
BytecodePtr:close()

local BytecodeArray = {}

for I = 1, #Bytecode do
  BytecodeArray[#BytecodeArray + 1] = tostring(Bytecode:byte(I))
end

local BytecodeString = "{ " .. table.concat(BytecodeArray, ", ") .. " }"

for _, CFileName in ipairs(CFiles) do
  local FilePtr = assert(io.open(CFileName, "rb"))
  local CFile = FilePtr:read("*a")
  FilePtr:close()

  CFile = CFile:gsub("BYTECODE", function()
    return BytecodeString
  end)

  ResultCFile = ResultCFile .. CFile
end

ResultCFile = EscapeString(ResultCFile)

local Result = string.format(BashFileFormat, ResultCFile)
local FilePtr = io.open("RuaVm.sh", "w")
FilePtr:write(Result)
FilePtr:close()
