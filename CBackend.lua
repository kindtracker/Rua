local CBackend = {}

--[[
  CBackend:

  Generate NewContext: Not Implemented
  Generate NewTable: Partially Implemented
  Generate Copy: Not Implemented
  Generate LoadString: Implemented
  Generate LoadNumber: Implemented
  Generate LoadBoolean: Implemented
  Generate LoadNil: Implemented
  Generate GetGlobal: Implemented
  Generate SetGlobal: Not Implemented
  Generate Push: Implemented
  Generate Pop: Implemented
  Generate ClearStack: Implemented
  Generate CallFunction: Implemented
  Generate Return: Implemented
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

#define REGISTER_CAPACITY 256
#define STACK_CAPACITY 256
#define CALLSTACK_CAPACITY 256

typedef enum {
  TypeNil,
  TypeBoolean,
  TypeNumber,
  TypeString,
  TypeFunction,
  TypeTable
} ValueTypeEnum;

typedef struct {
  ValueTypeEnum Type;
  void *Value;
} ValueType;

typedef struct {
  ValueType *Items;
  size_t Count;
  size_t Capacity;
} TableType;

typedef struct {
  uint32_t Address;
} FunctionType;

typedef struct {
  const char *Name;
  ValueType *Value;
} VariableType;

uint32_t Pc = 0;
bool Running = true;

Value *Registers[REGISTER_CAPACITY];
Value *Stack[STACK_CAPACITY];
int StackSize;
Value *CallStack[STACK_CAPACITY];
int CallStack;

void Push(ValueType *Register) {
  if (StackSize > STACK_CAPACITY) {
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

void Jump(uint32_t TargetPc) {
  if (CallStackSize > CALLSTACK_CAPACITY) {
    Running = false;
  }
  CallStack[CallStackSize++] = Pc;
  Pc = TargetPc;
}

void Return() {
  if (CallStackSize < 0) {
    Running = false;
  }
  Pc = CallStack[CallStackSize--];
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
  memset(&CallStack, 0, sizeof(CallStack));

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
      Register->Type = TypeString;
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

function CBackend:GenerateGetGlobal(State, Ir)
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

function CBackend:GenerateLoadNumber(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
      ValueType *ResultRegister = GetRegister(%d)
      ResultRegister->Type = TypeNumber;
      ResultRegister->Value = %d;
]],
    Ir[3],
    Ir[2]
  )
end

function CBackend:GenerateLoadBoolean(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
      ValueType *ResultRegister = GetRegister(%d)
      ResultRegister->Type = TypeBoolean;
      ResultRegister->Value = %s;
]],
    Ir[3],
    Ir[2] == true and "true" or "false"
  )
end

function CBackend:GenerateLoadNil(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
      ValueType *ResultRegister = GetRegister(%d)
      ResultRegister->Type = TypeNil;
]],
    Ir[3],
    Ir[2] == true and "true" or "false"
  )
end

function CBackend:GenerateNewTable(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
      TableType *Table = malloc(sizeof(TableType));
      if (!Table) {
        Running = false;
        return NULL;
      }

      Table->Count = 0;
      Table->Capacity = Capacity;
      Table->Items = calloc(Capacity, sizeof(ValueType));
      if (Capacity > 0 && !Table->Items) {
        free(Table);
        Running = false;
        return NULL;
      }

      memset(Table, 0, sizeof(TableType));
      memset(Table->Items, 0, sizeof(ValueType) * Capacity);

      ValueType *ResultRegister = GetRegister(%d);
      ResultRegister->Type = TypeTable;
      ResultRegister->Value = Table;
]],
    Ir[3],
    Ir[2] == true and "true" or "false"
  )
end

function CBackend:GenerateCallFunction(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
      ValueType *ResultRegister = GetRegister(%d);
      FunctionType *Function = (FunctionType)ResultRegister->Value;
      Jump(Function->Address);
  ]],
    Ir[2]
  )
end

function CBackend:GenerateReturnCode(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
      Return();
  ]]
  )
end

function CBackend:Generate(State, Ir)
  local GenerateIrTable = {
    LoadString = CBackend.GenerateLoadString,
    Push = CBackend.GeneratePush,
    Pop = CBackend.GeneratePop,
    ClearStack = CBackend.GenerateClearStack,
    GetGlobal = CBackend.GenerateGetGlobal,
    LoadNumber = CBackend.GenerateLoadNumber,
    LoadBoolean = CBackend.GenerateLoadBoolean,
    LoadNil = CBackend.GenerateLoadNil,
    NewTable = CBackend.GenerateNewTable,
    CallFunction = CBackend.GenerateCallFunction,
    Return = CBackend.GenerateReturn,
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
