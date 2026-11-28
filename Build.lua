local CFiles = {
  "Rua/Vm/Vm.h",
  "Rua/Vm/Main.c",
}

local BashFileFormat = [[
#!/usr/bin/env sh
VmSourceCode=%s

printf '%%s' "$VmSourceCode" > /tmp/rua_vm.c

CCompiler=$(command -v gcc || command -v clang || command -v g++ || command -v cc)
if [ -z "$CCompiler" ]; then
  echo "No C compiler found"
  exit 1
fi

$CCompiler /tmp/rua_vm.c -o /tmp/rua_vm
/tmp/rua_vm
]]
local ResultCFile = ""

function EscapeString(String)
  return "'" .. String:gsub("'", "'\\''") .. "'"
end

for _, CFileName in ipairs(CFiles) do
  local FilePtr = io.open(CFileName, "r")
  local CFile = FilePtr:read("*a")
  FilePtr:close()

  ResultCFile = ResultCFile .. CFile
end
ResultCFile = EscapeString(ResultCFile)

local Result = string.format(BashFileFormat, ResultCFile)
local FilePtr = io.open("RuaVm.sh", "w")
FilePtr:write(Result)
FilePtr:close()
