local CBackend = {}

--[[
  CBackend:

  Generate NewContext: Implemented
  Generate NewTable: Implemented
  Generate Copy: Implemented
  Generate LoadString: Implemented
  Generate LoadNumber: Implemented
  Generate LoadBoolean: Implemented
  Generate LoadNil: Implemented
  Generate GetGlobal: Implemented
  Generate SetGlobal: Implemented
  Generate Push: Implemented
  Generate Pop: Implemented
  Generate ClearStack: Implemented
  Generate CallFunction: Basic implementation
  Generate Return: Basic implementation
  Generate TablePush: Implemented
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
  Generate AstLabel: Not Implemented
  Generate AstGoto: Not Implemented
  Generate CreateFunction: Not Implemented
]]

function CBackend:PutFormatted(State, ...)
  State.CCode = State.CCode .. string.format(...)
end

local function EscapeCString(Value)
  local Parts = { '"' }

  for Idx = 1, #Value do
    local Byte = string.byte(Value, Idx)

    if Byte == 34 then
      Parts[#Parts + 1] = '\\"'
    elseif Byte == 92 then
      Parts[#Parts + 1] = "\\\\"
    elseif Byte == 10 then
      Parts[#Parts + 1] = "\\n"
    elseif Byte == 13 then
      Parts[#Parts + 1] = "\\r"
    elseif Byte == 9 then
      Parts[#Parts + 1] = "\\t"
    elseif Byte < 32 or Byte >= 127 then
      Parts[#Parts + 1] = string.format("\\%03o", Byte)
    else
      Parts[#Parts + 1] = string.char(Byte)
    end
  end

  Parts[#Parts + 1] = '"'

  return table.concat(Parts)
end

function CBackend:PutRuntimeStart(State)
  CBackend:PutFormatted(
    State,
    [[
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#define REGISTER_CAPACITY 256
#define STACK_CAPACITY 256
#define CALLSTACK_CAPACITY 256
#define GLOBAL_CAPACITY 256

#define Crash(...)           \
  do {                       \
    fprintf(stderr, __VA_ARGS__); \
    exit(1);                 \
  } while (0)

typedef enum {
  RuaNil,
  RuaBoolean,
  RuaNumber,
  RuaString,
  RuaFunction,
  RuaTable
} ValueTypeEnum;

typedef struct ValueType ValueType;
typedef struct TableType TableType;
typedef struct FunctionType FunctionType;
typedef struct ContextType ContextType;

struct ValueType {
  ValueTypeEnum Type;

  union {
    bool Boolean;
    double Number;
    const char *String;
    FunctionType *Function;
    TableType *Table;
  } Value;
};

struct TableType {
  ValueType *Items;
  size_t Count;
  size_t Capacity;
};

struct FunctionType {
  uint32_t Address;
};

struct ContextType {
  ValueType Registers[REGISTER_CAPACITY];
};

typedef struct {
  const char *Name;
  ValueType Value;
} GlobalType;

typedef struct {
  ContextType *PreviousContext;
  uint32_t ReturnAddress;
} CallFrameType;

uint32_t Pc = 1;
bool Running = true;

ContextType *CurrentContext = NULL;

ValueType Stack[STACK_CAPACITY];
int StackSize = 0;

CallFrameType CallStack[CALLSTACK_CAPACITY];
int CallStackSize = 0;

GlobalType Globals[GLOBAL_CAPACITY];
size_t GlobalCount = 0;

ContextType *CreateContext(void) {
  ContextType *Context = calloc(1, sizeof(ContextType));

  if (!Context) {
    Crash("0x%%x: CreateContext: Failed to allocate context", Pc);
  }

  return Context;
}

void NewContext(void) {
  ContextType *Context = CreateContext();

  if (!Context) {
    return;
  }

  if (CurrentContext) {
    free(CurrentContext);
  }

  CurrentContext = Context;
}

ValueType *GetRegister(int Register) {
  if (!CurrentContext ||
      Register < 0 ||
      Register >= REGISTER_CAPACITY) {
    Crash("0x%%x: GetRegister: Invalid register access (Register %%d)", Pc, Register);
  }

  return &CurrentContext->Registers[Register];
}

ValueType CreateNil(void) {
  ValueType Result = {0};
  Result.Type = RuaNil;
  return Result;
}

void PutNil(ValueType *Register) {
  if (Register) {
    *Register = CreateNil();
  }
}

void Push(ValueType *Register) {
  if (!Register) {
    Crash("0x%%x: Push: Attempt to push a NULL register", Pc);
  }

  if (StackSize >= STACK_CAPACITY) {
    Crash("0x%%x: Push: Stack overflow (Capacity %%d)", Pc, STACK_CAPACITY);
  }

  Stack[StackSize++] = *Register;
}

ValueType Pop(void) {
  if (StackSize <= 0) {
    Crash("0x%%x: Pop: Attempt to pop from an empty stack", Pc);
  }

  return Stack[--StackSize];
}

void ClearStack(void) {
  memset(Stack, 0, sizeof(Stack));
  StackSize = 0;
}

TableType *NewTable(size_t Capacity) {
  TableType *Table = calloc(1, sizeof(TableType));

  if (!Table) {
    Crash("0x%%x: NewTable: Failed to allocate table", Pc);
  }

  Table->Capacity = Capacity;

  if (Capacity > 0) {
    Table->Items = calloc(Capacity, sizeof(ValueType));

    if (!Table->Items) {
      free(Table);
      Crash("0x%%x: NewTable: Failed to allocate table items (Capacity %%zu)", Pc, Capacity);
    }
  }

  return Table;
}

void TablePush(TableType *Table, ValueType Value) {
  if (!Table) {
    Crash("0x%%x: TablePush: Attempt to push a value into a non-table", Pc);
  }

  if (Table->Count >= Table->Capacity) {
    size_t NewCapacity = Table->Capacity == 0
      ? 4
      : Table->Capacity * 2;

    ValueType *NewItems = realloc(
      Table->Items,
      NewCapacity * sizeof(ValueType)
    );

    if (!NewItems) {
      Crash("0x%%x: TablePush: Failed to reallocate table items (Capacity %%zu -> %%zu)", Pc, Table->Capacity, NewCapacity);
    }

    Table->Items = NewItems;
    Table->Capacity = NewCapacity;
  }

  Table->Items[Table->Count++] = Value;
}

void SetGlobal(const char *Name, ValueType Value) {
  for (size_t Idx = 0; Idx < GlobalCount; Idx++) {
    if (strcmp(Globals[Idx].Name, Name) == 0) {
      Globals[Idx].Value = Value;
      return;
    }
  }

  if (GlobalCount >= GLOBAL_CAPACITY) {
    Crash("0x%%x: SetGlobal: Global table overflow (Capacity %%d)", Pc, GLOBAL_CAPACITY);
  }

  Globals[GlobalCount].Name = Name;
  Globals[GlobalCount].Value = Value;
  GlobalCount++;
}

ValueType GetGlobal(const char *Name) {
  for (size_t Idx = 0; Idx < GlobalCount; Idx++) {
    if (strcmp(Globals[Idx].Name, Name) == 0) {
      return Globals[Idx].Value;
    }
  }

  return CreateNil();
}

void Jump(uint32_t TargetPc) {
  if (CallStackSize >= CALLSTACK_CAPACITY) {
    Crash("0x%%x: Jump: CallStack overflow (Capacity %%d)", Pc, CALLSTACK_CAPACITY);
  }

  ContextType *Context = CreateContext();
  CallFrameType *Frame = &CallStack[CallStackSize++];

  Frame->PreviousContext = CurrentContext;
  Frame->ReturnAddress = Pc;

  CurrentContext = Context;
  Pc = TargetPc - 1;
}

void Return(void) {
  if (CallStackSize <= 0) {
    Crash("0x%%x: Return: Attempt to return without an active function call", Pc);
  }

  CallFrameType Frame = CallStack[--CallStackSize];

  free(CurrentContext);

  CurrentContext = Frame.PreviousContext;
  Pc = Frame.ReturnAddress;
}

void Execute(void) {
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
    Crash("0x%%x: Execute: Program counter out of bounds", Pc);
    break;
  }
}

int main(void) {
  while (Running) {
    Execute();

    if (Running) {
      Pc++;
    }
  }

  while (CallStackSize > 0) {
    free(CurrentContext);

    CallFrameType Frame = CallStack[--CallStackSize];
    CurrentContext = Frame.PreviousContext;
  }

  return 0;
}
]]
  )
end

function CBackend:GenerateLoadString(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *Register = GetRegister(%d);

    if (Register) {
      Register->Type = RuaString;
      Register->Value.String = %s;
    }
]],
    Ir[3],
    EscapeCString(Ir[2])
  )
end

function CBackend:GenerateLoadNumber(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *Register = GetRegister(%d);

    if (Register) {
      Register->Type = RuaNumber;
      Register->Value.Number = %g;
    }
]],
    Ir[3],
    Ir[2]
  )
end

function CBackend:GenerateLoadBoolean(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *Register = GetRegister(%d);

    if (Register) {
      Register->Type = RuaBoolean;
      Register->Value.Boolean = %s;
    }
]],
    Ir[3],
    Ir[2] and "true" or "false"
  )
end

function CBackend:GenerateLoadNil(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *Register = GetRegister(%d);

    if (Register) {
      PutNil(Register);
    }
]],
    Ir[2]
  )
end

function CBackend:GenerateNewContext(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    NewContext();
]]
  )
end

function CBackend:GeneratePopContext(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    free(CurrentContext);
    CallFrameType Frame = CallStack[--CallStackSize];
    CurrentContext = Frame.PreviousContext;
    Return();
]]
  )
end

function CBackend:GenerateCopy(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *Source = GetRegister(%d);
    ValueType *Destination = GetRegister(%d);

    if (SourceRegister && DestinationRegister) {
      *DestinationRegister = *SourceRegister;
    }
]],
    Ir[2],
    Ir[3]
  )
end

function CBackend:GenerateNewTable(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *ResultRegister = GetRegister(%d);

    if (Result) {
      ResultRegister->Type = RuaTable;
      ResultRegister->Value.Table = NewTable(%d);
    }
]],
    Ir[3],
    Ir[2]
  )
end

function CBackend:GenerateTablePush(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *TableRegister = GetRegister(%d);
    ValueType *ValueRegister = GetRegister(%d);

    if (TableRegister &&
        ValueRegister &&
        TableRegister->Type == RuaTable) {
      TablePush(TableRegister->Value.Table, *ValueRegister);
    } else {
      Crash("0x%x: TablePush: Attempt to push a value into a non-table (Register %d)", Pc, Register);
    }
]],
    Ir[2],
    Ir[3],
    Ir[2]
  )
end

function CBackend:GeneratePush(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *Register = GetRegister(%d);

    if (Register) {
      Push(Register);
    }
]],
    Ir[2]
  )
end

function CBackend:GeneratePop(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *Register = GetRegister(%d);

    if (Register) {
      *Register = Pop();
    }
]],
    Ir[2]
  )
end

function CBackend:GenerateClearStack(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ClearStack();
]]
  )
end

function CBackend:GenerateGetGlobal(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *Result = GetRegister(%d);
    ValueType *Name = GetRegister(%d);

    if (Result && Name && Name->Type == RuaString) {
      *Result = GetGlobal(Name->Value.String);
    }
]],
    Ir[2],
    Ir[3]
  )
end

function CBackend:GenerateSetGlobal(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *Name = GetRegister(%d);
    ValueType *Value = GetRegister(%d);

    if (Name && Value && Name->Type == RuaString) {
      SetGlobal(Name->Value.String, *Value);
    }
]],
    Ir[2],
    Ir[3]
  )
end

function CBackend:GenerateCallFunction(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *Register = GetRegister(%d);

    if (Register && Register->Type == RuaFunction &&
        Register->Value.Function) {
      Jump(Register->Value.Function->Address);
    } else {
      Crash("0x%%x: CallFunction: Attempt to call a value a non-function value (Register %%d)", Pc, %d);
    }
]],
    Ir[2],
    Ir[2]
  )
end

function CBackend:GenerateReturn(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    Return();
]]
  )
end

function CBackend:Generate(State, Ir)
  local GenerateIrTable = {
    NewContext = CBackend.GenerateNewContext,
    NewTable = CBackend.GenerateNewTable,
    PopContext = CBackend.GeneratePopContext,
    Copy = CBackend.GenerateCopy,
    LoadString = CBackend.GenerateLoadString,
    LoadNumber = CBackend.GenerateLoadNumber,
    LoadBoolean = CBackend.GenerateLoadBoolean,
    LoadNil = CBackend.GenerateLoadNil,
    GetGlobal = CBackend.GenerateGetGlobal,
    SetGlobal = CBackend.GenerateSetGlobal,
    Push = CBackend.GeneratePush,
    Pop = CBackend.GeneratePop,
    ClearStack = CBackend.GenerateClearStack,
    TablePush = CBackend.GenerateTablePush,
    CallFunction = CBackend.GenerateCallFunction,
    Return = CBackend.GenerateReturn,
  }

  local GenerateIr = GenerateIrTable[Ir[1]]

  if GenerateIr then
    GenerateIr(CBackend, State, Ir)

    CBackend:PutFormatted(
      State,
      [[
    break;
]]
    )
  else
    CBackend:PutFormatted(
      State,
      [[
    // Couldn't find a handler for %q
    break;
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
  case %d: {
]],
      State.Pc
    )

    CBackend:Generate(State, Ir)

    CBackend:PutFormatted(
      State,
      [[
  }
]]
    )

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

    CBackend:PutFormatted(
      State,
      [[
  // Label %d
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
