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
  Generate CallFunction: Implemented
  Generate Return: Implemented
  Generate TablePush: Implemented
  Generate NewFunction: Implemented
  Generate Index: Implemented
  Generate NewIndex: Implemented
  Generate Jump: Implemented
  Generate JumpIfTrue: Implemented

  Generate Add: Implemented
  Generate Subtract: Implemented
  Generate Multiply: Implemented
  Generate Divide: Implemented
  Generate Modulo: Implemented
  Generate Power: Implemented
  Generate Negate: Implemented
  Generate Not: Implemented
  Generate And: Implemented
  Generate Or: Implemented
  Generate Equal: Implemented
  Generate NotEqual: Implemented
  Generate LessThan: Implemented
  Generate LessThanOrEqual: Implemented
  Generate GreaterThan: Implemented
  Generate GreaterThanOrEqual: Implemented
]]

function CBackend:CreateState(Ir, IrFunctions)
  return {
    CCode = "",
    Pc = 1,

    Ir = Ir or {},
    IrFunctions = IrFunctions or {},
  }
end

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
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <limits.h>

#define REGISTER_CAPACITY 256
#define STACK_CAPACITY 256
#define CALLSTACK_CAPACITY 256
#define GLOBAL_CAPACITY 256

#define Crash(...)              \
  do {                           \
    fflush(stdout);               \
    fprintf(stderr, __VA_ARGS__); \
    fputc('\n', stderr);          \
    exit(1);                      \
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

typedef void (*RuaCFunction)(void);

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

typedef struct {
  ValueType Key;
  ValueType Value;
} TableFieldType;

struct TableType {
  TableFieldType *Fields;
  size_t Count;
  size_t Capacity;
};

struct FunctionType {
  uint32_t Address;
  RuaCFunction CFunction;
  bool IsCFunction;
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
bool PcChanged = false;

ContextType *CurrentContext = NULL;

ValueType Stack[STACK_CAPACITY];
int StackSize = 0;

CallFrameType CallStack[CALLSTACK_CAPACITY];
int CallStackSize = 0;

GlobalType Globals[GLOBAL_CAPACITY];
size_t GlobalCount = 0;

static ContextType *CreateContext(void) {
  ContextType *Context = calloc(1, sizeof(ContextType));

  if (!Context) {
    Crash("0x%%x: CreateContext: Failed to allocate context", Pc);
  }

  return Context;
}

static void NewContext(void) {
  if (CallStackSize > 0) {
    Crash("0x%%x: NewContext: Cannot replace a context during a function call", Pc);
  }

  free(CurrentContext);
  CurrentContext = CreateContext();
}

static ValueType *GetRegister(int Register) {
  if (!CurrentContext ||
      Register < 0 ||
      Register >= REGISTER_CAPACITY) {
    Crash("0x%%x: GetRegister: Invalid register access (Register %%d)", Pc, Register);
  }

  return &CurrentContext->Registers[Register];
}

static ValueType CreateNil(void) {
  ValueType Result = {0};
  Result.Type = RuaNil;
  return Result;
}

static void PutNil(ValueType *Register) {
  if (Register) {
    *Register = CreateNil();
  }
}

static void Push(ValueType *Register) {
  if (!Register) {
    Crash("0x%%x: Push: Attempt to push a NULL register", Pc);
  }

  if (StackSize >= STACK_CAPACITY) {
    Crash("0x%%x: Push: Stack overflow (Capacity %%d)", Pc, STACK_CAPACITY);
  }

  Stack[StackSize++] = *Register;
}

static ValueType Pop(void) {
  if (StackSize <= 0) {
    Crash("0x%%x: Pop: Attempt to pop from an empty stack", Pc);
  }

  return Stack[--StackSize];
}

static void ClearStack(void) {
  memset(Stack, 0, sizeof(Stack));
  StackSize = 0;
}

static TableType *NewTable(size_t Capacity) {
  TableType *Table = calloc(1, sizeof(TableType));

  if (!Table) {
    Crash("0x%%x: NewTable: Failed to allocate table", Pc);
  }

  if (Capacity > SIZE_MAX / sizeof(TableFieldType)) {
    free(Table);
    Crash("0x%%x: NewTable: Table capacity overflow", Pc);
  }

  Table->Capacity = Capacity;

  if (Capacity > 0) {
    Table->Fields = calloc(Capacity, sizeof(TableFieldType));

    if (!Table->Fields) {
      free(Table);
      Crash("0x%%x: NewTable: Failed to allocate table fields", Pc);
    }
  }

  return Table;
}

static bool ValuesEqual(ValueType Left, ValueType Right) {
  if (Left.Type != Right.Type) {
    return false;
  }

  switch (Left.Type) {
    case RuaNil:
      return true;

    case RuaBoolean:
      return Left.Value.Boolean == Right.Value.Boolean;

    case RuaNumber:
      return Left.Value.Number == Right.Value.Number;

    case RuaString:
      if (!Left.Value.String || !Right.Value.String) {
        return Left.Value.String == Right.Value.String;
      }

      return strcmp(Left.Value.String, Right.Value.String) == 0;

    case RuaFunction:
      return Left.Value.Function == Right.Value.Function;

    case RuaTable:
      return Left.Value.Table == Right.Value.Table;
  }

  return false;
}

static void TablePush(TableType *Table, ValueType Key, ValueType Value) {
  if (!Table) {
    Crash("0x%%x: TablePush: Attempt to push a field into a non-table", Pc);
  }

  if (Key.Type == RuaNil) {
    Crash("0x%%x: TablePush: Table index is nil", Pc);
  }

  if (Table->Count >= Table->Capacity) {
    size_t NewCapacity = Table->Capacity == 0
      ? 4
      : Table->Capacity * 2;

    if (NewCapacity < Table->Capacity ||
        NewCapacity > SIZE_MAX / sizeof(TableFieldType)) {
      Crash("0x%%x: TablePush: Table capacity overflow", Pc);
    }

    TableFieldType *NewFields = realloc(
      Table->Fields,
      NewCapacity * sizeof(TableFieldType)
    );

    if (!NewFields) {
      Crash("0x%%x: TablePush: Failed to allocate table fields", Pc);
    }

    Table->Fields = NewFields;
    Table->Capacity = NewCapacity;
  }

  Table->Fields[Table->Count++] = (TableFieldType) {
    .Key = Key,
    .Value = Value
  };
}

static ValueType TableIndex(TableType *Table, ValueType Key) {
  if (!Table) {
    Crash("0x%%x: TableIndex: Attempt to index a non-table", Pc);
  }

  if (Key.Type == RuaNil) {
    Crash("0x%%x: TableIndex: Table index is nil", Pc);
  }

  for (size_t Idx = 0; Idx < Table->Count; Idx++) {
    TableFieldType *Field = &Table->Fields[Idx];

    if (ValuesEqual(Field->Key, Key)) {
      return Field->Value;
    }
  }

  return CreateNil();
}

static void TableNewIndex(TableType *Table, ValueType Key, ValueType Value) {
  if (!Table) {
    Crash("0x%%x: TableNewIndex: Attempt to newindex a non-table", Pc);
  }

  if (Key.Type == RuaNil) {
    Crash("0x%%x: TableNewIndex: Table index is nil", Pc);
  }

  for (size_t Idx = 0; Idx < Table->Count; Idx++) {
    TableFieldType *Field = &Table->Fields[Idx];

    if (ValuesEqual(Field->Key, Key)) {
      if (Value.Type == RuaNil) {
        memmove(
          &Table->Fields[Idx],
          &Table->Fields[Idx + 1],
          (Table->Count - Idx - 1) * sizeof(TableFieldType)
        );

        Table->Count--;
      } else {
        Field->Value = Value;
      }

      return;
    }
  }

  if (Value.Type != RuaNil) {
    TablePush(Table, Key, Value);
  }
}

static void SetGlobal(const char *Name, ValueType Value) {
  if (!Name) {
    Crash("0x%%x: SetGlobal: Attempt to use a NULL global name", Pc);
  }

  for (size_t Idx = 0; Idx < GlobalCount; Idx++) {
    if (strcmp(Globals[Idx].Name, Name) == 0) {
      Globals[Idx].Value = Value;
      return;
    }
  }

  if (Value.Type == RuaNil) {
    return;
  }

  if (GlobalCount >= GLOBAL_CAPACITY) {
    Crash("0x%%x: SetGlobal: Global table overflow", Pc);
  }

  Globals[GlobalCount].Name = Name;
  Globals[GlobalCount].Value = Value;
  GlobalCount++;
}

static ValueType GetGlobal(const char *Name) {
  if (!Name) {
    Crash("0x%%x: GetGlobal: Attempt to use a NULL global name", Pc);
  }

  for (size_t Idx = 0; Idx < GlobalCount; Idx++) {
    if (strcmp(Globals[Idx].Name, Name) == 0) {
      return Globals[Idx].Value;
    }
  }

  return CreateNil();
}

static void Jump(uint32_t TargetPc) {
  if (CallStackSize >= CALLSTACK_CAPACITY) {
    Crash("0x%%x: Jump: CallStack overflow", Pc);
  }

  if (TargetPc == 0) {
    Crash("0x%%x: Jump: Invalid target address", Pc);
  }

  ContextType *Context = CreateContext();

  CallFrameType *Frame = &CallStack[CallStackSize++];

  Frame->PreviousContext = CurrentContext;
  Frame->ReturnAddress = Pc + 1;

  CurrentContext = Context;

  Pc = TargetPc;
  PcChanged = true;
}

static void Return(void) {
  if (CallStackSize <= 0) {
    Crash("0x%%x: Return: Attempt to return without an active function call", Pc);
  }

  CallFrameType Frame = CallStack[--CallStackSize];

  free(CurrentContext);

  CurrentContext = Frame.PreviousContext;
  Pc = Frame.ReturnAddress;

  PcChanged = true;
}

]]
  )
end

function CBackend:PutApiCode(State)
  CBackend:PutFormatted(
    State,
    [[
void RuaPushNil(void) {
  ValueType Result = CreateNil();
  Push(&Result);
}

void RuaPushBoolean(bool Value) {
  ValueType Result = {0};
  Result.Type = RuaBoolean;
  Result.Value.Boolean = Value;
  Push(&Result);
}

void RuaPushNumber(double Value) {
  ValueType Result = {0};
  Result.Type = RuaNumber;
  Result.Value.Number = Value;
  Push(&Result);
}

void RuaPushString(const char *Value) {
  ValueType Result = {0};
  Result.Type = RuaString;
  Result.Value.String = Value;
  Push(&Result);
}

void RuaPop(void) {
  (void)Pop();
}

double RuaPopNumber(void) {
  ValueType Value = Pop();

  if (Value.Type != RuaNumber) {
    Crash("RuaPopNumber: Expected a number");
  }

  return Value.Value.Number;
}

const char *RuaPopString(void) {
  ValueType Value = Pop();

  if (Value.Type != RuaString) {
    Crash("RuaPopString: Expected a string");
  }

  return Value.Value.String;
}

bool RuaPopBoolean(void) {
  ValueType Value = Pop();

  if (Value.Type != RuaBoolean) {
    Crash("RuaPopBoolean: Expected a boolean");
  }

  return Value.Value.Boolean;
}

void RuaGetGlobal(const char *Name) {
  ValueType Result = GetGlobal(Name);
  Push(&Result);
}

void RuaSetGlobal(const char *Name) {
  SetGlobal(Name, Pop());
}

void RuaCreateTable(void) {
  ValueType Result = {0};
  Result.Type = RuaTable;
  Result.Value.Table = NewTable(0);
  Push(&Result);
}

void RuaPushCFunction(RuaCFunction Function) {
  if (!Function) {
    Crash("RuaPushCFunction: Attempt to create a NULL function");
  }

  FunctionType *Result = calloc(1, sizeof(FunctionType));

  if (!Result) {
    Crash("RuaPushCFunction: Failed to allocate function");
  }

  Result->CFunction = Function;
  Result->IsCFunction = true;

  ValueType Value = {0};
  Value.Type = RuaFunction;
  Value.Value.Function = Result;

  Push(&Value);
}

]]
  )
end

function CBackend:PutLuaRuntime(State)
  CBackend:PutFormatted(
    State,
    [[
static void Print(void) {
  const char *String = RuaPopString();
  printf("%%s\n", String);
}

static void LuaRuntimeInitialize(void) {
  RuaPushCFunction(Print);
  RuaSetGlobal("print");
}

]]
  )
end

function CBackend:GenerateLoadString(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *Register = GetRegister(%d);

    Register->Type = RuaString;
    Register->Value.String = %s;
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

    Register->Type = RuaNumber;
    Register->Value.Number = %.17g;
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

    Register->Type = RuaBoolean;
    Register->Value.Boolean = %s;
]],
    Ir[3],
    Ir[2] and "true" or "false"
  )
end

function CBackend:GenerateLoadNil(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    PutNil(GetRegister(%d));
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
    if (CallStackSize <= 0) {
      free(CurrentContext);
      CurrentContext = NULL;
      Running = false;
    } else {
      Return();
    }
]]
  )
end

function CBackend:GenerateCopy(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *SourceRegister = GetRegister(%d);
    ValueType *DestinationRegister = GetRegister(%d);

    *DestinationRegister = *SourceRegister;
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

    ResultRegister->Type = RuaTable;
    ResultRegister->Value.Table = NewTable(%d);
]],
    Ir[2],
    Ir[3] or 0
  )
end

function CBackend:GenerateNewFunction(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *ResultRegister = GetRegister(%d);

    FunctionType *Function = calloc(1, sizeof(FunctionType));

    if (!Function) {
      Crash("0x%%x: NewFunction: Failed to allocate function", Pc);
    }

    Function->Address = %d;
    Function->IsCFunction = false;

    ResultRegister->Type = RuaFunction;
    ResultRegister->Value.Function = Function;
]],
    Ir[2],
    Ir[3]
  )
end

function CBackend:GeneratePush(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    Push(GetRegister(%d));
]],
    Ir[2]
  )
end

function CBackend:GeneratePop(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    *GetRegister(%d) = Pop();
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
    ValueType *Name = GetRegister(%d);
    ValueType *Result = GetRegister(%d);

    if (Name->Type != RuaString) {
      Crash("0x%%x: GetGlobal: Expected a string global name", Pc);
    }

    *Result = GetGlobal(Name->Value.String);
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

    if (Name->Type != RuaString) {
      Crash("0x%%x: SetGlobal: Expected a string global name", Pc);
    }

    SetGlobal(Name->Value.String, *Value);
]],
    Ir[2],
    Ir[3]
  )
end

function CBackend:GenerateTablePush(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *TableRegister = GetRegister(%d);
    ValueType *ValueRegister = GetRegister(%d);

    if (TableRegister->Type != RuaTable) {
      Crash("0x%%x: TablePush: Expected a table", Pc);
    }

    ValueType Key = {0};
    Key.Type = RuaNumber;
    Key.Value.Number =
      (double)(TableRegister->Value.Table->Count + 1);

    TablePush(
      TableRegister->Value.Table,
      Key,
      *ValueRegister
    );
]],
    Ir[2],
    Ir[3]
  )
end

function CBackend:GenerateIndex(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *TableRegister = GetRegister(%d);
    ValueType *KeyRegister = GetRegister(%d);
    ValueType *ResultRegister = GetRegister(%d);

    if (TableRegister->Type != RuaTable) {
      Crash("0x%%x: TableIndex: Attempt to index a non-table", Pc);
    }

    *ResultRegister = TableIndex(
      TableRegister->Value.Table,
      *KeyRegister
    );
]],
    Ir[2],
    Ir[3],
    Ir[4]
  )
end

function CBackend:GenerateNewIndex(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *TableRegister = GetRegister(%d);
    ValueType *KeyRegister = GetRegister(%d);
    ValueType *ValueRegister = GetRegister(%d);

    if (TableRegister->Type != RuaTable) {
      Crash("0x%%x: TableNewIndex: Attempt to newindex a non-table", Pc);
    }

    TableNewIndex(
      TableRegister->Value.Table,
      *KeyRegister,
      *ValueRegister
    );
]],
    Ir[2],
    Ir[3],
    Ir[4]
  )
end

function CBackend:GenerateCallFunction(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *Register = GetRegister(%d);

    if (Register->Type != RuaFunction ||
        !Register->Value.Function) {
      Crash("0x%%x: CallFunction: Attempt to call a non-function value (Register %%d)", Pc, %d);
    }

    FunctionType *Function = Register->Value.Function;

    if (Function->IsCFunction) {
      Function->CFunction();
    } else {
      Jump(Function->Address);
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

local function GenerateNumericBinary(State, Ir, Name, Expression)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *LeftRegister = GetRegister(%d);
    ValueType *RightRegister = GetRegister(%d);
    ValueType *ResultRegister = GetRegister(%d);

    if (LeftRegister->Type != RuaNumber ||
        RightRegister->Type != RuaNumber) {
      Crash("0x%%x: %s: Expected number operands", Pc);
    }

    ResultRegister->Type = RuaNumber;
    ResultRegister->Value.Number = %s;
]],
    Ir[2],
    Ir[3],
    Ir[4],
    Name,
    Expression
  )
end

function CBackend:GenerateAdd(State, Ir)
  GenerateNumericBinary(State, Ir, "Add", "LeftRegister->Value.Number + RightRegister->Value.Number")
end

function CBackend:GenerateSubtract(State, Ir)
  GenerateNumericBinary(State, Ir, "Subtract", "LeftRegister->Value.Number - RightRegister->Value.Number")
end

function CBackend:GenerateMultiply(State, Ir)
  GenerateNumericBinary(State, Ir, "Multiply", "LeftRegister->Value.Number * RightRegister->Value.Number")
end

function CBackend:GenerateDivide(State, Ir)
  GenerateNumericBinary(State, Ir, "Divide", "LeftRegister->Value.Number / RightRegister->Value.Number")
end

function CBackend:GenerateModulo(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *LeftRegister = GetRegister(%d);
    ValueType *RightRegister = GetRegister(%d);
    ValueType *ResultRegister = GetRegister(%d);

    if (LeftRegister->Type != RuaNumber ||
        RightRegister->Type != RuaNumber) {
      Crash("0x%%x: Modulo: Expected number operands", Pc);
    }

    double Left = LeftRegister->Value.Number;
    double Right = RightRegister->Value.Number;
    double Value = fmod(Left, Right);

    if (Right == 0.0) {
      Value = INFINITY;
    } else {
      if (Value != 0.0 &&
          ((Value < 0.0) != (Right < 0.0))) {
        Value += Right;
      }
    }


    ResultRegister->Type = RuaNumber;
    ResultRegister->Value.Number = Value;
]],
    Ir[2],
    Ir[3],
    Ir[4]
  )
end

function CBackend:GeneratePower(State, Ir)
  GenerateNumericBinary(State, Ir, "Power", "pow(LeftRegister->Value.Number, RightRegister->Value.Number)")
end

function CBackend:GenerateNegate(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *OperandRegister = GetRegister(%d);
    ValueType *ResultRegister = GetRegister(%d);

    if (OperandRegister->Type != RuaNumber) {
      Crash("0x%%x: Negate: Expected a number", Pc);
    }

    ResultRegister->Type = RuaNumber;
    ResultRegister->Value.Number =
      -OperandRegister->Value.Number;
]],
    Ir[2],
    Ir[3]
  )
end

function CBackend:GenerateNot(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *OperandRegister = GetRegister(%d);
    ValueType *ResultRegister = GetRegister(%d);

    ResultRegister->Type = RuaBoolean;
    ResultRegister->Value.Boolean =
      OperandRegister->Type == RuaNil ||
      (OperandRegister->Type == RuaBoolean &&
       !OperandRegister->Value.Boolean);
]],
    Ir[2],
    Ir[3]
  )
end

function CBackend:GenerateAnd(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *LeftRegister = GetRegister(%d);
    ValueType *RightRegister = GetRegister(%d);
    ValueType *ResultRegister = GetRegister(%d);

    if (LeftRegister->Type == RuaNil ||
        (LeftRegister->Type == RuaBoolean &&
         !LeftRegister->Value.Boolean)) {
      *ResultRegister = *LeftRegister;
    } else {
      *ResultRegister = *RightRegister;
    }
]],
    Ir[2],
    Ir[3],
    Ir[4]
  )
end

function CBackend:GenerateOr(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *LeftRegister = GetRegister(%d);
    ValueType *RightRegister = GetRegister(%d);
    ValueType *ResultRegister = GetRegister(%d);

    if (LeftRegister->Type == RuaNil ||
        (LeftRegister->Type == RuaBoolean &&
         !LeftRegister->Value.Boolean)) {
      *ResultRegister = *RightRegister;
    } else {
      *ResultRegister = *LeftRegister;
    }
]],
    Ir[2],
    Ir[3],
    Ir[4]
  )
end

local function GenerateComparison(State, Ir, Name, Operator)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *LeftRegister = GetRegister(%d);
    ValueType *RightRegister = GetRegister(%d);
    ValueType *ResultRegister = GetRegister(%d);

    int Comparison = 0;

    if (LeftRegister->Type == RuaNumber &&
        RightRegister->Type == RuaNumber) {
      double Left = LeftRegister->Value.Number;
      double Right = RightRegister->Value.Number;

      Comparison = (Left > Right) - (Left < Right);
    } else if (LeftRegister->Type == RuaString &&
               RightRegister->Type == RuaString) {

      if (!LeftRegister->Value.String ||
          !RightRegister->Value.String) {
        Crash("0x%%x: %s: Invalid string operand", Pc);
      }

      Comparison = strcmp(
        LeftRegister->Value.String,
        RightRegister->Value.String
      );
    } else {
      Crash("0x%%x: %s: Expected two numbers or two strings", Pc);
    }

    ResultRegister->Type = RuaBoolean;
    ResultRegister->Value.Boolean = Comparison %s 0;
]],
    Ir[2],
    Ir[3],
    Ir[4],
    Name,
    Operator
  )
end

local function GenerateEquality(State, Ir, Negate)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *LeftRegister = GetRegister(%d);
    ValueType *RightRegister = GetRegister(%d);
    ValueType *ResultRegister = GetRegister(%d);

    bool Equal = ValuesEqual(
      *LeftRegister,
      *RightRegister
    );

    ResultRegister->Type = RuaBoolean;
    ResultRegister->Value.Boolean = %s;
]],
    Ir[2],
    Ir[3],
    Ir[4],
    Negate and "!Equal" or "Equal"
  )
end

function CBackend:GenerateEqual(State, Ir)
  GenerateEquality(State, Ir, false)
end

function CBackend:GenerateNotEqual(State, Ir)
  GenerateEquality(State, Ir, true)
end

function CBackend:GenerateLessThan(State, Ir)
  GenerateComparison(State, Ir, "LessThan", "<")
end

function CBackend:GenerateLessThanOrEqual(State, Ir)
  GenerateComparison(State, Ir, "LessThanOrEqual", "<=")
end

function CBackend:GenerateGreaterThan(State, Ir)
  GenerateComparison(State, Ir, "GreaterThan", ">")
end

function CBackend:GenerateGreaterThanOrEqual(State, Ir)
  GenerateComparison(State, Ir, "GreaterThanOrEqual", ">=")
end

function CBackend:GenerateJump(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    Jump(%d);
]],
    Ir[2]
  )
end

function CBackend:GenerateJumpIfTrue(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *ValueRegister = GetRegister(%d);

    if (ValueRegister->Type != RuaNil &&
        !(ValueRegister->Type == RuaBoolean &&
          !ValueRegister->Value.Boolean)) {
      Jump(%d);
    }
]],
    Ir[2],
    Ir[3]
  )
end

function CBackend:Generate(State, Ir)
  local GenerateIrTable = {
    NewContext = CBackend.GenerateNewContext,
    NewTable = CBackend.GenerateNewTable,
    NewFunction = CBackend.GenerateNewFunction,
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
    Index = CBackend.GenerateIndex,
    NewIndex = CBackend.GenerateNewIndex,
    CallFunction = CBackend.GenerateCallFunction,
    Return = CBackend.GenerateReturn,
    Add = CBackend.GenerateAdd,
    Sub = CBackend.GenerateSubtract,
    Multiply = CBackend.GenerateMultiply,
    Divide = CBackend.GenerateDivide,
    Mod = CBackend.GenerateModulo,
    Pow = CBackend.GeneratePower,
    And = CBackend.GenerateAnd,
    Or = CBackend.GenerateOr,
    Equal = CBackend.GenerateEqual,
    NotEqual = CBackend.GenerateNotEqual,
    LessThan = CBackend.GenerateLessThan,
    LessThanOrEqual = CBackend.GenerateLessThanOrEqual,
    GreaterThan = CBackend.GenerateGreaterThan,
    GreaterThanOrEqual = CBackend.GenerateGreaterThanOrEqual,
    Negative = CBackend.GenerateNegate,
    Not = CBackend.GenerateNot,
    Jump = CBackend.GenerateJump,
    JumpIfTrue = CBackend.GenerateJumpIfTrue,
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

function CBackend:PutRuntimeEnd(State)
  CBackend:PutFormatted(
    State,
    [[
int main(int Argc, char *Argv[]) {
  (void)Argc;
  (void)Argv;

  LuaRuntimeInitialize();

#ifdef RUA_USER_INITIALIZE
  RuaUserInitialize();
#endif

  while (Running) {
    PcChanged = false;

    Execute();

    if (Running && !PcChanged) {
      Pc++;
    }
  }

  while (CallStackSize > 0) {
    free(CurrentContext);

    CallFrameType Frame = CallStack[--CallStackSize];
    CurrentContext = Frame.PreviousContext;
  }

  free(CurrentContext);
  CurrentContext = NULL;

  return 0;
}
]]
  )
end

function CBackend:Compile(State, FileName, OutputFile, Data)
  State = State or CBackend:CreateState()

  State.CCode = ""
  State.Pc = 1

  State.Ir = State.Ir or {}
  State.IrFunctions = State.IrFunctions or {}

  CBackend:PutRuntimeStart(State)
  CBackend:PutApiCode(State)
  CBackend:PutLuaRuntime(State)

  CBackend:PutFormatted(
    State,
    [[
static void Execute(void) {
  switch (Pc) {
    // Main
]]
  )

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

    CBackend:GenerateBlock(State, Function.IrProgram)
  end

  CBackend:PutFormatted(
    State,
    [[
  default:
    Crash("0x%%x: Execute: Program counter out of bounds", Pc);
    break;
  }
}

]]
  )

  CBackend:PutRuntimeEnd(State)

  if OutputFile then
    local CFile, Error = io.open(OutputFile, "w")

    if not CFile then
      error("CBackend: Failed to open output file: " .. tostring(Error))
    end

    local Success, WriteError = CFile:write(State.CCode)

    if not Success then
      CFile:close()
      error("CBackend: Failed to write output file: " .. tostring(WriteError))
    end

    CFile:close()
  end

  return State.CCode
end

return CBackend
