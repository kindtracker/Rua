local CBackend = {}

function CBackend:PutFormatted(State, ...)
  State.CCode = State.CCode .. string.format(...)
end

function CBackend:PutRuntimeStart(State)
  CBackend:PutFormatted(
    State,
    [[
#include <stdbool.h>

typedef enum {
  Nil,
  Boolean,
  Number,
  String,
  Function,
  Table
} ValueType;

typedef struct {
  ValueType Type;
  void *Value;
} Value;

#define REGISTER_COUNT 256
#define STACK_COUNT 256

uint32_t Pc = 0;
bool Running = true;

Value Registers[REGISTER_COUNT];
Value Stack[STACK_COUNT];
int StackSize;

void Push(Value Register) {
  if (StackSize > STACK_COUNT) {
    Running = false;
  }
  Stack[StackSize++] = *Register;
}

Value Pop() {
  if (StackSize < 0) {
    Running = false;
  }
  return Stack[StackSize--];
}

void Execute() {
  switch (Pc) {
    // Main
]]
  )
end

function CBackend:PutRuntimeEnd(State)
  CBackend:PutFormatted(
    State,
    [[

    default:
      Running = false;
  }
}

int main() {
  while (Running) {
    Execute();
    Pc++;
  }
}
]]
  )
end

function CBackend:GenerateLoadString(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
      Value *Register = GetRegister(%d);
      Register->Type = RuaTypeString;
      Register->Value = %q;
]],
    Ir[3],
    Ir[2]
  )
end

function CBackend:GeneratePush(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
      Value *Register = GetRegister(%d);
      Push(*Register);
]],
    Ir[2]
  )
end

function CBackend:GenerateClearStack(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
      memset(&Stack, 0, sizeof(Stack));
]],
    Ir[2]
  )
end

function CBackend:Generate(State, Ir)
  local GenerateIrTable = {
    LoadString = CBackend.GenerateLoadString,
    Push = CBackend.GeneratePush,
    ClearStack = CBackend.GenerateClearStack,
  }

  local IrInstruction = Ir[1]
  if GenerateIrTable[IrInstruction] then
    GenerateIrTable[IrInstruction](CBackend, State, Ir)
    CBackend:PutFormatted(State, "\n")
  else
    CBackend:PutFormatted(
      State,
      [[
      // Couldn't find a handler for %q
]],
      Ir[1]
    )
  end
end

function CBackend:GenerateBlock(State, IrProgram)
  for _, Ir in ipairs(IrProgram) do
    CBackend:PutFormatted(
      State,
      [[
    case %d:
]],
      State.Pc
    )
    CBackend:Generate(State, Ir)

    State.Pc = State.Pc + 1
  end
end

function CBackend:Compile(State, FileName, OutputFile, Data)
  State.CCode = ""
  State.Pc = 1

  CBackend:PutRuntimeStart(State)

  CBackend:GenerateBlock(State, State.Ir)
  for _, Function in ipairs(State.IrFunctions) do
    CBackend:PutFormatted(State, "\n")
    CBackend:PutFormatted(State, [[
      // Label%d
]] .. "\n", Function.Label)
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
