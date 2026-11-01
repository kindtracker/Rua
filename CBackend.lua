local CBackend = {}

--[[
  CBackend:

  Generate NewContext: Not Implemented
  Generate NewTable: Not Implemented
  Generate Copy: Not Implemented
  Generate LoadString: Implemented
  Generate LoadNumber: Not Implemented
  Generate LoadBoolean: Not Implemented
  Generate LoadNil: Not Implemented
  Generate GetVariable: Implemented
  Generate SetVariable: Not Implemented
  Generate Push: Implemented
  Generate Pop: Implemented
  Generate ClearStack: Implemented
  Generate CallFunction: Not Implemented
  Generate CallFunctionFromRegister: Not Implemented
  Generate Return: Not Implemented
  Generate Add: Not Implemented
  Generate Subtract: Not Implemented
  Generate Multiply: Not Implemented
  Generate Divide: Not Implemented
  Generate Modulo: Not Implemented
  Generate Power: Not Implemented
  Generate Negate: Not Implemented
  Generate Not: Not Implemented
  Generate And: Not Implemented
  Generate Or: Not Implemented
  Generate Equal: Not Implemented
  Generate NotEqual: Not Implemented
  Generate LessThan: Not Implemented
  Generate LessThanOrEqual: Not Implemented
  Generate GreaterThan: Not Implemented
  Generate GreaterThanOrEqual: Not Implemented
  Generate Index: Not Implemented
  Generate NewIndex: Not Implemented
  Generate TablePush: Not Implemented
  Generate Label: Not Implemented
  Generate Goto: Not Implemented
  Generate Break: Not Implemented
  Generate Function: Not Implemented
  Generate If: Not Implemented
  Generate While: Not Implemented
]]

function CBackend:PutFormatted(State, ...)
  State.CCode = State.CCode .. string.format(...)
end

function CBackend:PutRuntimeStart(State)
  CBackend:PutFormatted(
    State,
    [[
#include <string.h>
#include <stdbool.h>

#define REGISTER_COUNT 256
#define STACK_COUNT 256

typedef enum {
  Nil,
  Boolean,
  Number,
  String,
  Function,
  Table
} ValueTypeEnum;

typedef struct {
  ValueTypeEnum Type;
  void *Value;
} ValueType;

typedef struct {
  const char *Name;
  ValueType *Value;
} VariableType;

uint32_t Pc = 0;
bool Running = true;

Value *Registers[REGISTER_COUNT];
Value *Stack[STACK_COUNT];
int StackSize;

void Push(ValueType *Register) {
  if (StackSize > STACK_COUNT) {
    Running = false;
  }
  Stack[StackSize++] = Register;
}

Value *Pop() {
  if (StackSize < 0) {
    Running = false;
  }
  return Stack[StackSize--];
}

void PutNil(ValueType *Register) {
  Register->Type = Nil;
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
  memset(&Registers, 0, sizeof(Registers));
  memset(&Stack, 0, sizeof(Stack));

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
      ValueType *Register = GetRegister(%d);
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
      ValueType *Register = GetRegister(%d);
      Push(*Register);
]],
    Ir[2]
  )
end

function CBackend:GeneratePop(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
      ValueType *Register = GetRegister(%d);
      ValueType Value = Pop();
      memcpy(Register, &Value, sizeof(ValueType));
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

function CBackend:GenerateGetVariable(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
      ValueType *ResultRegister = GetRegister(%d)
      ValueType *NameRegister = GetRegister(%d)
      const char *Name = NameRegister->Value;

      for (int Idx = 0; Idx < sizeof(Variables) / sizeof(Value); Idx++) {
        VariableType *Variable = Variables[Idx];

        if (strcmp(Variable->Name, Name) == 0) {
          memcpy(ResultRegister, &Value, sizeof(ValueType));
          break;
        }
      }

      PutNil(ResultRegister);
]],
    Ir[2],
    Ir[3]
  )
end

function CBackend:Generate(State, Ir)
  local GenerateIrTable = {
    LoadString = CBackend.GenerateLoadString,
    Push = CBackend.GeneratePush,
    Pop = CBackend.GeneratePop,
    ClearStack = CBackend.GenerateClearStack,
    GetVariable = CBackend.GenerateGetVariable,
  }

  local IrInstruction = Ir[1]
  if GenerateIrTable[IrInstruction] then
    GenerateIrTable[IrInstruction](CBackend, State, Ir)
    CBackend:PutFormatted(State, [[
      break
]] .. "\n")
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
