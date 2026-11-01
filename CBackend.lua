local CBackend = {}

function CBackend:PutFormatted(State, ...)
  State.CCode = State.CCode .. string.format(...)
end

function CBackend:PutRuntimeStart(State)
  CBackend:PutFormatted(
    State,
    [[
int main() {
  Main:
]]
  )
end

function CBackend:PutRuntimeEnd(State)
  CBackend:PutFormatted(
    State,
    [[
}
]]
  )
end

function CBackend:GenerateLoadString(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    RegisterType *Register = GetRegister(%d);
    Register->Type = RuaTypeString;
    Register->Value = %q;
]],
    Ir[3],
    Ir[2]
  )
end

function CBackend:Generate(State, Ir)
  local GenerateIrTable = {
    LoadString = CBackend.GenerateLoadString,
  }

  local IrInstruction = Ir[1]
  if GenerateIrTable[IrInstruction] then
    GenerateIrTable[IrInstruction](CBackend, State, Ir)
  else
    CBackend:PutFormatted(
      State,
      [[
  // Couldn't find a handler for %s Ir instruction
]],
      Ir[1]
    )
  end
end

function CBackend:GenerateBlock(State, IrProgram)
  for _, Ir in ipairs(IrProgram) do
    CBackend:Generate(State, Ir)
  end
end

function CBackend:Compile(State, FileName, OutputFile, Data)
  State.CCode = ""

  CBackend:PutRuntimeStart(State)

  CBackend:GenerateBlock(State, State.Ir)
  for _, Function in ipairs(State.IrFunctions) do
    CBackend:PutFormatted(State, "\n")
    CBackend:PutFormatted(
      State,
      [[
  Label%d:
]],
      Function.Label
    )
    CBackend:GenerateBlock(State, Function)
  end

  CBackend:PutRuntimeEnd(State)

  if OutputFile then
    local CFile = io.open(OutputFile, "w")
    CFile:write(State.CCode)
    CFile:close()
  end

  return State.CCode
end

return CBackend
