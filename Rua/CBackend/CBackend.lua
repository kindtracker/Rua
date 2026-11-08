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
  Generate JumpIfFalse: Implemented

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

function CBackend:PutFormatted(State, ...)
  CBackend.CCode = CBackend.CCode .. string.format(...)
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

    break;
]]
  )
end

function CBackend:GenerateCopy(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *SourceRegister = GetRegisterUpvalue(%d);
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
      Crash("0x%%%%x: NewFunction: Failed to allocate function", Pc);
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
    Push(GetRegisterUpvalue(%d));
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
    ValueType *Name = GetRegisterUpvalue(%d);
    ValueType *Result = GetRegister(%d);

    if (Name->Type != RuaString) {
      Crash("0x%%%%x: GetGlobal: Expected a string global name", Pc);
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
      Crash("0x%%%%x: SetGlobal: Expected a string global name", Pc);
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
    ValueType *TableRegister = GetRegisterUpvalue(%d);
    ValueType *ValueRegister = GetRegisterUpvalue(%d);

    if (TableRegister->Type != RuaTable) {
      Crash("0x%%%%x: TablePush: Expected a table", Pc);
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
    ValueType *TableRegister = GetRegisterUpvalue(%d);
    ValueType *KeyRegister = GetRegisterUpvalue(%d);
    ValueType *ResultRegister = GetRegister(%d);

    if (TableRegister->Type != RuaTable) {
      Crash("0x%%%%x: TableIndex: Attempt to index a non-table", Pc);
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
    ValueType *TableRegister = GetRegisterUpvalue(%d);
    ValueType *KeyRegister = GetRegisterUpvalue(%d);
    ValueType *ValueRegister = GetRegisterUp(%d);

    if (TableRegister->Type != RuaTable) {
      Crash("0x%%%%x: TableNewIndex: Attempt to newindex a non-table", Pc);
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
    ValueType *Register = GetRegisterUpvalue(%d);

    if (Register->Type != RuaFunction ||
        !Register->Value.Function) {
      Crash("0x%%%%x: CallFunction: Attempt to call a non-function value (Register %d)", Pc);
    }

    FunctionType *Function = Register->Value.Function;

    if (Function->IsCFunction) {
      Function->CFunction();
    } else {
      Jump(Function->Address);
      break;
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
    ValueType *LeftRegister = GetRegisterUpvalue(%d);
    ValueType *RightRegister = GetRegisterUpvalue(%d);
    ValueType *ResultRegister = GetRegister(%d);

    if (LeftRegister->Type != RuaNumber ||
        RightRegister->Type != RuaNumber) {
      Crash("0x%%%%x: %s: Expected number operands", Pc);
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
    ValueType *LeftRegister = GetRegisterUpvalue(%d);
    ValueType *RightRegister = GetRegisterUpvalue(%d);
    ValueType *ResultRegister = GetRegister(%d);

    if (LeftRegister->Type != RuaNumber ||
        RightRegister->Type != RuaNumber) {
      Crash("0x%%%%x: Modulo: Expected number operands", Pc);
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
    ValueType *OperandRegister = GetRegisterUpvalue(%d);
    ValueType *ResultRegister = GetRegister(%d);

    if (OperandRegister->Type != RuaNumber) {
      Crash("0x%%%%x: Negate: Expected a number", Pc);
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
    ValueType *LeftRegister = GetRegisterUpvalue(%d);
    ValueType *RightRegister = GetRegisterUpvalue(%d);
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
    ValueType *LeftRegister = GetRegisterUpvalue(%d);
    ValueType *RightRegister = GetRegisterUpvalue(%d);
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
    ValueType *LeftRegister = GetRegisterUpvalue(%d);
    ValueType *RightRegister = GetRegisterUpvalue(%d);
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
        Crash("0x%%%%x: %s: Invalid string operand", Pc);
      }

      Comparison = strcmp(
        LeftRegister->Value.String,
        RightRegister->Value.String
      );
    } else {
      Crash("0x%%%%x: %s: Expected two numbers or two strings", Pc);
    }

    ResultRegister->Type = RuaBoolean;
    ResultRegister->Value.Boolean = Comparison %s 0;
]],
    Ir[2],
    Ir[3],
    Ir[4],
    Name,
    Name,
    Operator
  )
end

local function GenerateEquality(State, Ir, Negate)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *LeftRegister = GetRegisterUpvalue(%d);
    ValueType *RightRegister = GetRegisterUpvalue(%d);
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
    break;
]],
    Ir[2]
  )
end

function CBackend:GenerateJumpIfTrue(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *ValueRegister = GetRegisterUpvalue(%d);

    if (ValueRegister->Type != RuaNil &&
        !(ValueRegister->Type == RuaBoolean &&
          !ValueRegister->Value.Boolean)) {
      Jump(%d);
      break;
    }
]],
    Ir[2],
    Ir[3]
  )
end

function CBackend:GenerateJumpIfFalse(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    ValueType *ValueRegister = GetRegisterUpvalue(%d);

    if (ValueRegister->Type == RuaNil ||
        (ValueRegister->Type == RuaBoolean &&
          !ValueRegister->Value.Boolean)) {
      Jump(%d);
      break;
    }
]],
    Ir[2],
    Ir[3]
  )
end

function CBackend:GenerateChangeFile(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    FileName = %q;
]],
    Ir[2]
  )
end

function CBackend:GenerateChangeRow(State, Ir)
  CBackend:PutFormatted(
    State,
    [[
    Row = %d;
]],
    Ir[2]
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
    JumpIfFalse = CBackend.GenerateJumpIfFalse,
    File = CBackend.GenerateChangeFile,
    Row = CBackend.GenerateChangeRow,
  }

  local GenerateIr = GenerateIrTable[Ir[1]]

  if GenerateIr then
    CBackend:PutFormatted(
      State,
      [[
    Pc = %d;
]],
      CBackend.Pc
    )

    GenerateIr(CBackend, State, Ir)

    CBackend:PutFormatted(
      State,
      [[
]]
    )
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

function CBackend:GenerateBlock(State, IrProgram, IsLast)
  for Idx, Ir in ipairs(IrProgram) do
    local IsLastIr = (Idx == #IrProgram) and IsLast

    CBackend:PutFormatted(
      State,
      [[
  case %d: {
]],
      CBackend.Pc
    )
    CBackend:Generate(State, Ir)

    if IsLastIr then
      CBackend:PutFormatted(
        State,
        [[
    break;
]]
      )
    end

    CBackend:PutFormatted(
      State,
      [[
  }
]]
    )

    CBackend.Pc = CBackend.Pc + 1
  end
end

function CBackend:PutRuaExecuteIr(State)
  CBackend:PutFormatted(
    State,
    [[
static void RuaExecuteIr() {
  switch (Pc) {
    // Main
]]
  )

  CBackend:GenerateBlock(State, State.Ir, #State.IrFunctions == 0)
  for Idx, Function in ipairs(State.IrFunctions) do
    CBackend:PutFormatted(State, "\n")
    CBackend:PutFormatted(
      State,
      [[
  // Label %d
]],
      Function.Label
    )

    local IsLast = Idx == #State.IrFunctions
    CBackend:GenerateBlock(State, Function.IrProgram, IsLast)
  end

  CBackend:PutFormatted(
    State,
    [[
  default:
    Crash("0x%%%%x: Execute: Program counter out of bounds", Pc);
    break;
  }
}

]]
  )
end

function CBackend:UseRuaRuntime(State, File)
  State.RuaRuntimeFile = File
end

function CBackend:Compile(State, FileName, OutputFile, Arguments)
  State = State
  CBackend.CCode = ""
  CBackend.Pc = 1

  local RuaRuntimeFilePtr = io.open(State.RuaRuntimeFile)
  local RuaRuntime = RuaRuntimeFilePtr:read("*a")
  RuaRuntimeFilePtr:close()

  CBackend:PutRuaExecuteIr(State)
  local RuaExecuteIrCode = CBackend.CCode

  RuaRuntime = RuaRuntime:gsub("// RuaExecuteIr", RuaExecuteIrCode)
  CBackend.CCode = RuaRuntime .. "\n"

  if Arguments.AddMain then
    CBackend:PutFormatted(
      State,
      [[
int main(int Argc, char *Argv[]) {
  return RuaDefaultEntryPoint(Argc, Argv);
}]]
    )
  end

  if OutputFile then
    local CFile, Error = io.open(OutputFile, "w")

    if not CFile then
      error("CBackend: Failed to open output file: " .. tostring(Error))
    end

    local Success, WriteError = CFile:write(CBackend.CCode)

    if not Success then
      CFile:close()
      error("CBackend: Failed to write output file: " .. tostring(WriteError))
    end

    CFile:close()
  end

  State.CCode = CBackend.CCode
  return CBackend.CCode
end

return CBackend
