local IrGenerator = {}

local function HashString(String)
  local Hash = 5381

  for Character in String:gmatch(".") do
    Hash = ((Hash << 5) + Hash) + string.byte(Character)
  end

  return Hash
end

local function HashTable(Ast)
  local Hash = 72

  for Index, Value in pairs(Ast) do
    local IndexHash = type(Index) == "table" and IrGenerator:HashTable(Index)
      or type(Index) == "string" and HashString(Index)
      or Index

    local ValueHash
    if type(Value) == "table" then
      ValueHash = IrGenerator:HashTable(Value)
    elseif type(Value) == "number" then
      ValueHash = Value
    elseif type(Value) == "string" then
      ValueHash = HashString(Value)
    elseif type(Value) == "boolean" then
      ValueHash = Value and 1 or 0
    else
      ValueHash = 0
    end

    Hash = ((Hash << 5) + Hash) + IndexHash + ValueHash
  end

  return Hash
end

function IrGenerator:Reset(State)
  IrGenerator.Contexts = {}
  State.IrFunctions = {}
  IrGenerator.Pc = 0
  IrGenerator.EndLabels = {}
  IrGenerator.AstLabels = {}
  IrGenerator.Labels = {}
  IrGenerator.LabelId = 1

  State.Ir = {}
end

function IrGenerator:NewLabel(State)
  local Label = IrGenerator.LabelId
  IrGenerator.LabelId = IrGenerator.LabelId + 1

  return Label
end

function IrGenerator:PushContext(State, GenerateNewContext)
  local Parent = IrGenerator.Contexts[#IrGenerator.Contexts]

  local Context = {
    Registers = {},
    IrProgram = {},
    Locals = {},
  }

  for Idx = 1, 256 do
    Context.Registers[Idx] = Parent and Parent.Registers[Idx] or false
  end

  IrGenerator.Registers = Context.Registers
  IrGenerator.IrProgram = Context.IrProgram
  table.insert(IrGenerator.Contexts, Context)

  if GenerateNewContext then
    IrGenerator.Ir = {
      [1] = "NewContext",
    }
    IrGenerator:NewIr(State)
  end
end

function IrGenerator:PopContext(State, ExtraCode)
  local Context = table.remove(IrGenerator.Contexts)
  local Parent = IrGenerator.Contexts[#IrGenerator.Contexts]

  table.insert(Context.IrProgram, {
    [1] = "PopContext",
  })

  for _, Ir in ipairs(ExtraCode or {}) do
    table.insert(Context.IrProgram, Ir)
  end

  if Parent then
    Context.Parent = Parent
    table.insert(State.IrFunctions, Context)
  else
    for _, Ir in ipairs(Context.IrProgram) do
      table.insert(State.Ir, Ir)
    end
  end

  if Parent then
    IrGenerator.Registers = Parent.Registers
    IrGenerator.IrProgram = Parent.IrProgram
  end
end

function IrGenerator:AllocateRegister(State)
  for Idx, Register in ipairs(IrGenerator.Registers) do
    if not Register then
      Register = true
      IrGenerator.Registers[Idx] = true
      return Idx
    end
  end

  Logger:Error(State, "InternalError", "Couldn't allocate a register")
end

function IrGenerator:MarkNotUsed(State, Register)
  for Idx = #IrGenerator.Contexts, 1, -1 do
    local Scope = IrGenerator.Contexts[Idx].Locals

    for _, VariableRegister in pairs(Scope) do
      if VariableRegister == Register then
        return
      end
    end
  end

  IrGenerator.Registers[Register] = false
end

function IrGenerator:NewIr(State)
  local Ir = IrGenerator.Ir
  table.insert(IrGenerator.IrProgram, Ir)

  IrGenerator.Ir = {}
end

function IrGenerator:GetCurrentScope(State)
  local CurrentContext = IrGenerator.Contexts[#IrGenerator.Contexts]
  return CurrentContext.Locals
end

function IrGenerator:GenerateBody(State, Ast, Label, ExtraCode, ExtraStartCode)
  IrGenerator:PushContext(State, true)

  local Context = IrGenerator.Contexts[#IrGenerator.Contexts]
  Context.Label = Label

  for _, Ir in ipairs(ExtraStartCode or {}) do
    IrGenerator.Ir = Ir
    IrGenerator:NewIr(State)
  end

  for _, Child in ipairs(Ast) do
    IrGenerator:Generate(State, Child)
  end

  for _, Ir in ipairs(ExtraCode or {}) do
    IrGenerator.Ir = Ir
    IrGenerator:NewIr(State)
  end

  IrGenerator:PopContext(State)
end

function IrGenerator:AddLocalVariableRegister(State, Ast, VariableRegister)
  local AstString = HashTable(Ast)
  local CurrentScope = IrGenerator:GetCurrentScope(State)
  CurrentScope[AstString] = VariableRegister
end

function IrGenerator:GenerateIdentifier(State, Ast, Data)
  local AstString = HashTable(Ast)
  for Idx = #IrGenerator.Contexts, 1, -1 do
    local Scope = IrGenerator.Contexts[Idx].Locals
    local VariableRegister = Scope[AstString]

    if VariableRegister then
      return VariableRegister
    end
  end

  local ResultRegister
  if not Data then
    local NameRegister = IrGenerator:Generate(State, Ast.Name)
    ResultRegister = IrGenerator:AllocateRegister(State)

    IrGenerator.Ir = {
      [1] = "GetGlobal",
      [2] = NameRegister,
      [3] = ResultRegister,
    }
    IrGenerator:NewIr(State)
    IrGenerator:MarkNotUsed(State, NameRegister)
  end

  return ResultRegister
end

function IrGenerator:GenerateString(State, Ast, Data)
  local ResultRegister = IrGenerator:AllocateRegister(State)

  IrGenerator.Ir = {
    [1] = "LoadString",
    [2] = Ast.Value or Ast,
    [3] = ResultRegister,
  }
  IrGenerator:NewIr(State)

  return ResultRegister
end

function IrGenerator:GenerateFunctionCall(State, Ast, Data)
  local FunctionRegister = IrGenerator:Generate(State, Ast.Name)
  local ResultRegister = IrGenerator:AllocateRegister(State)

  for Idx = #Ast.Arguments, 1, -1 do
    local Argument = Ast.Arguments[Idx]
    local ArgumentRegister = IrGenerator:Generate(State, Argument)

    IrGenerator.Ir = {
      [1] = "Push",
      [2] = ArgumentRegister,
    }
    IrGenerator:NewIr(State)
    IrGenerator:MarkNotUsed(State, ArgumentRegister)
  end

  if not FunctionRegister then
    FunctionRegister = IrGenerator:AllocateRegister(State)
  end

  IrGenerator.Ir = {
    [1] = "CallFunction",
    [2] = FunctionRegister,
  }
  IrGenerator:NewIr(State)
  IrGenerator:MarkNotUsed(State, FunctionRegister)

  local ResultRegisters = {}
  local ResultCount = Data or 0

  for Idx = 1, ResultCount do
    local ResultRegister = IrGenerator:AllocateRegister(State)
    ResultRegisters[Idx] = ResultRegister

    IrGenerator.Ir = {
      [1] = "Pop",
      [2] = ResultRegister,
    }
    IrGenerator:NewIr(State)
  end

  IrGenerator.Ir = {
    [1] = "ClearStack",
  }
  IrGenerator:NewIr(State)

  return ResultRegisters
end

function IrGenerator:GenerateVariableAssign(State, Ast, Data)
  local ValuesRegisters = {}

  for _, Value in ipairs(Ast.Value) do
    if Value.Kind == "FunctionCall" then
      local ResultRegisters = IrGenerator:Generate(State, Value, #Ast.Name)
      for _, ResultRegister in ipairs(ResultRegisters) do
        table.insert(ValuesRegisters, ResultRegister)
      end
    else
      local ValueRegister = IrGenerator:Generate(State, Value)
      table.insert(ValuesRegisters, ValueRegister)
    end
  end

  for Index, Name in ipairs(Ast.Name) do
    local ValueRegister = ValuesRegisters[Index]

    if Name.Kind == "Member" then
      local TableRegister = IrGenerator:Generate(State, Name.Table)
      local KeyRegister = IrGenerator:Generate(State, Name.Name)

      IrGenerator.Ir = {
        [1] = "NewIndex",
        [2] = TableRegister,
        [3] = KeyRegister,
        [4] = ValueRegister,
      }
      IrGenerator:NewIr(State)
      IrGenerator:MarkNotUsed(State, TableRegister)
      IrGenerator:MarkNotUsed(State, KeyRegister)
    else
      if Ast.Local then
        local VariableRegister = IrGenerator:Generate(State, Name, Ast.Local)

        if not VariableRegister then
          VariableRegister = IrGenerator:AllocateRegister(State)
        end

        IrGenerator:AddLocalVariableRegister(State, Name, VariableRegister)
        IrGenerator.Ir = {
          [1] = "Copy",
          [2] = ValueRegister,
          [3] = VariableRegister,
        }
        IrGenerator:NewIr(State)
        IrGenerator:MarkNotUsed(State, VariableRegister)
      else
        local NameRegister = IrGenerator:Generate(State, Name.Name, Ast.Local)

        IrGenerator.Ir = {
          [1] = "SetGlobal",
          [2] = NameRegister,
          [3] = ValueRegister,
        }
        IrGenerator:NewIr(State)
        IrGenerator:MarkNotUsed(State, NameRegister)
      end

      IrGenerator:MarkNotUsed(State, ValueRegister)
    end
  end

  for _, ValueRegister in ipairs(ValuesRegisters) do
    IrGenerator:MarkNotUsed(State, ValueRegister)
  end
end

function IrGenerator:GenerateFunction(State, Ast, Data)
  local ResultRegister = IrGenerator:AllocateRegister(State)
  local BodyLabel = IrGenerator:NewLabel(State)

  IrGenerator.Ir = {
    [1] = "NewFunction",
    [2] = ResultRegister,
    [3] = BodyLabel,
  }
  IrGenerator:NewIr(State)

  IrGenerator:PushContext(State, true)
  local Context = IrGenerator.Contexts[#IrGenerator.Contexts]
  Context.Label = BodyLabel

  for _, Argument in ipairs(Ast.Arguments) do
    local ArgumentRegister = IrGenerator:AllocateRegister(State)
    IrGenerator:AddLocalVariableRegister(State, Argument, ArgumentRegister)

    IrGenerator.Ir = {
      [1] = "Pop",
      [2] = ArgumentRegister,
    }
    IrGenerator:NewIr(State)
  end

  for _, Child in ipairs(Ast.Body) do
    IrGenerator:Generate(State, Child)
  end

  IrGenerator:PopContext(State, { {
    [1] = "Return",
  } })

  return ResultRegister
end

function IrGenerator:GenerateNumber(State, Ast, Data)
  local ResultRegister = IrGenerator:AllocateRegister(State)

  IrGenerator.Ir = {
    [1] = "LoadNumber",
    [2] = Ast.Value,
    [3] = ResultRegister,
  }
  IrGenerator:NewIr(State)

  return ResultRegister
end

function IrGenerator:GenerateBoolean(State, Ast, Data)
  local ResultRegister = IrGenerator:AllocateRegister(State)

  IrGenerator.Ir = {
    [1] = "LoadBoolean",
    [2] = Ast.Value,
    [3] = ResultRegister,
  }
  IrGenerator:NewIr(State)

  return ResultRegister
end

function IrGenerator:GenerateNil(State, Ast, Data)
  local ResultRegister = IrGenerator:AllocateRegister(State)

  IrGenerator.Ir = {
    [1] = "LoadNil",
    [2] = ResultRegister,
  }
  IrGenerator:NewIr(State)

  return ResultRegister
end

function IrGenerator:GenerateWhile(State, Ast, Data)
  local BodyLabel = IrGenerator:NewLabel(State)
  local ConditionLabel = IrGenerator:NewLabel(State)
  local EndLabel = IrGenerator:NewLabel(State)

  table.insert(IrGenerator.EndLabels, EndLabel)

  IrGenerator.Ir = {
    "Jump",
    ConditionLabel,
  }
  IrGenerator:NewIr(State)

  IrGenerator:PushContext(State, true)

  local Context = IrGenerator.Contexts[#IrGenerator.Contexts]
  Context.Label = ConditionLabel

  local ConditionRegister = IrGenerator:Generate(State, Ast.Condition)

  IrGenerator:MarkNotUsed(State, ConditionRegister)

  IrGenerator.Ir = {
    "JumpIfTrue",
    ConditionRegister,
    BodyLabel,
  }
  IrGenerator:NewIr(State)

  IrGenerator.Ir = {
    "Jump",
    EndLabel,
  }
  IrGenerator:NewIr(State)

  IrGenerator:PopContext(State)
  IrGenerator:GenerateBody(State, Ast.Body, BodyLabel, {
    {
      "Jump",
      ConditionLabel,
    },
  })

  IrGenerator:GenerateBody(State, {}, EndLabel)

  table.remove(IrGenerator.EndLabels)
end

function IrGenerator:GenerateBinary(State, Ast, Data)
  local ResultRegister = IrGenerator:AllocateRegister(State)
  local LeftRegister = IrGenerator:Generate(State, Ast.Left)
  local RightRegister = IrGenerator:Generate(State, Ast.Right)

  local BinaryOpcodes = {
    ["+"] = "Add",
    ["-"] = "Sub",
    ["/"] = "Divide",
    ["*"] = "Multiply",
    ["%"] = "Mod",
    ["^"] = "Pow",
    ["&"] = "NumberAnd",
    ["|"] = "NumberOr",
    ["~"] = "NumberXor",
    ["=="] = "Equal",
    ["~="] = "NotEqual",
    [">="] = "GreaterThanOrEqual",
    ["<="] = "LessThanOrEqual",
    [">"] = "GreaterThan",
    ["<"] = "LessThan",
    ["and"] = "And",
    ["or"] = "Or",
  }
  local Opcode = BinaryOpcodes[Ast.Operator]

  IrGenerator.Ir = {
    [1] = Opcode,
    [2] = LeftRegister,
    [3] = RightRegister,
    [4] = ResultRegister,
  }
  IrGenerator:NewIr(State)
  IrGenerator:MarkNotUsed(State, LeftRegister)
  IrGenerator:MarkNotUsed(State, RightRegister)

  return ResultRegister
end

function IrGenerator:GenerateUnary(State, Ast, Data)
  local ResultRegister = IrGenerator:AllocateRegister(State)
  local OperandRegister = IrGenerator:Generate(State, Ast.Operand)

  local UnaryOpcodes = {
    ["-"] = "Negative",
    ["#"] = "Length",
    ["not"] = "Not",
  }
  local Opcode = UnaryOpcodes[Ast.Operator]

  IrGenerator.Ir = {
    [1] = Opcode,
    [2] = OperandRegister,
    [3] = ResultRegister,
  }
  IrGenerator:NewIr(State)
  IrGenerator:MarkNotUsed(State, OperandRegister)

  return ResultRegister
end

function IrGenerator:GenerateReturn(State, Ast, Data)
  for Idx = #Ast.Value, 1, -1 do
    local Value = Ast.Value[Idx]
    local ValueRegister = IrGenerator:Generate(State, Value)

    IrGenerator.Ir = {
      [1] = "Push",
      [2] = ValueRegister,
    }
    IrGenerator:NewIr(State)
    IrGenerator:MarkNotUsed(State, ValueRegister)
  end
end

function IrGenerator:GenerateIf(State, Ast, Data)
  local BodyLabel = IrGenerator:NewLabel(State)
  local ElseBodyLabel = IrGenerator:NewLabel(State)
  local ConditionRegister = IrGenerator:Generate(State, Ast.Condition, Data)

  IrGenerator.Ir = {
    [1] = "JumpIfTrue",
    [2] = ConditionRegister,
    [3] = BodyLabel,
  }
  IrGenerator:NewIr(State)
  IrGenerator:GenerateBody(State, Ast.Body, BodyLabel)

  if Ast.Else then
    IrGenerator.Ir = {
      [1] = "JumpIfFalse",
      [2] = ConditionRegister,
      [3] = ElseBodyLabel,
    }
    IrGenerator:NewIr(State)
    IrGenerator:GenerateBody(State, Ast.Else, ElseBodyLabel)
  end

  IrGenerator:MarkNotUsed(State, ConditionRegister)
end

function IrGenerator:GenerateTable(State, Ast, Data)
  local ResultRegister = IrGenerator:AllocateRegister(State)

  IrGenerator.Ir = {
    [1] = "NewTable",
    [2] = ResultRegister,
  }
  IrGenerator:NewIr(State)

  for _, Field in pairs(Ast.Fields) do
    IrGenerator:Generate(State, Field, ResultRegister)
  end

  return ResultRegister
end

function IrGenerator:GenerateKeyValue(State, Ast, Data)
  local KeyRegister = IrGenerator:Generate(State, Ast.Key)
  local ValueRegister = IrGenerator:Generate(State, Ast.Value)

  IrGenerator.Ir = {
    [1] = "NewIndex",
    [2] = Data,
    [3] = KeyRegister,
    [4] = ValueRegister,
  }
  IrGenerator:NewIr(State)
  IrGenerator:MarkNotUsed(State, KeyRegister)
  IrGenerator:MarkNotUsed(State, ValueRegister)
end

function IrGenerator:GenerateArrayValue(State, Ast, Data)
  local ValueRegister = IrGenerator:Generate(State, Ast.Value)

  IrGenerator.Ir = {
    [1] = "TablePush",
    [2] = Data,
    [3] = ValueRegister,
  }
  IrGenerator:NewIr(State)
  IrGenerator:MarkNotUsed(State, ValueRegister)
end

function IrGenerator:GenerateMember(State, Ast, Data)
  local TableRegister = IrGenerator:Generate(State, Ast.Table)
  local KeyRegister = IrGenerator:Generate(State, Ast.Name)
  local ResultRegister = IrGenerator:AllocateRegister(State)

  IrGenerator.Ir = {
    [1] = "Index",
    [2] = TableRegister,
    [3] = KeyRegister,
    [4] = ResultRegister,
  }
  IrGenerator:NewIr(State)
  IrGenerator:MarkNotUsed(State, TableRegister)
  IrGenerator:MarkNotUsed(State, KeyRegister)

  return ResultRegister
end

function IrGenerator:GenerateLabel(State, Ast, Data)
  IrGenerator.AstLabels[Ast.Name] = IrGenerator.LabelId
  IrGenerator.Ir = {
    [1] = "UserLabel",
    [2] = IrGenerator.LabelId,
  }
  IrGenerator:NewIr(State)

  IrGenerator.LabelId = IrGenerator.LabelId + 1
end

function IrGenerator:GenerateGoto(State, Ast, Data)
  IrGenerator.Ir = {
    [1] = "UserGoto",
    [2] = IrGenerator.AstLabels[Ast.Name],
  }
  IrGenerator:NewIr(State)
end

function IrGenerator:GenerateBreak(State, Ast, Data)
  local EndLabel = IrGenerator.EndLabels[#IrGenerator.EndLabels]

  IrGenerator.Ir = {
    [1] = "Jump",
    [2] = EndLabel,
  }
  IrGenerator:NewIr(State)
end

function IrGenerator:GenerateChangeRow(State, Ast, Data)
  if Ast.Row then
    IrGenerator.Ir = {
      [1] = "Row",
      [2] = Ast.Row,
    }
    IrGenerator:NewIr(State)
  end
end

function IrGenerator:GenerateGroup(State, Ast, Data)
  return IrGenerator:Generate(Ast.Expression)
end

function IrGenerator:Generate(State, Ast, Data)
  IrGenerator:GenerateChangeRow(State, Ast)

  if type(Ast) == "string" or Ast.Kind == "String" then
    local ResultRegister = IrGenerator:GenerateString(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "FunctionCall" then
    local ResultRegister = IrGenerator:GenerateFunctionCall(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "VariableAssign" then
    local ResultRegister = IrGenerator:GenerateVariableAssign(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "Identifier" then
    local ResultRegister = IrGenerator:GenerateIdentifier(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "Number" then
    local ResultRegister = IrGenerator:GenerateNumber(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "Boolean" then
    local ResultRegister = IrGenerator:GenerateBoolean(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "Nil" then
    local ResultRegister = IrGenerator:GenerateNil(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "Function" then
    local ResultRegister = IrGenerator:GenerateFunction(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "While" then
    local ResultRegister = IrGenerator:GenerateWhile(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "Binary" then
    local ResultRegister = IrGenerator:GenerateBinary(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "Unary" then
    local ResultRegister = IrGenerator:GenerateUnary(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "Return" then
    local ResultRegister = IrGenerator:GenerateReturn(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "If" then
    local ResultRegister = IrGenerator:GenerateIf(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "Table" then
    local ResultRegister = IrGenerator:GenerateTable(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "KeyValue" then
    local ResultRegister = IrGenerator:GenerateKeyValue(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "ArrayValue" then
    local ResultRegister = IrGenerator:GenerateArrayValue(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "Member" then
    local ResultRegister = IrGenerator:GenerateMember(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "Label" then
    local ResultRegister = IrGenerator:GenerateLabel(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "Goto" then
    local ResultRegister = IrGenerator:GenerateGoto(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "Break" then
    local ResultRegister = IrGenerator:GenerateBreak(State, Ast, Data)
    return ResultRegister
  elseif Ast.Kind == "Group" then
    local ResultRegister = IrGenerator:GenerateGroup(State, Ast, Data)
    return ResultRegister
  else
    Logger:Error(
      State,
      "InternalError",
      "Couldn't find a handler for %s when generating Ir for it",
      Ast.Kind or (type(Ast) .. " (type)")
    )
  end
end

function IrGenerator:CountPc(State, IrProgram)
  IrGenerator.Pc = IrGenerator.Pc + #IrProgram
end

function IrGenerator:FindLabels(State)
  IrGenerator.Labels = {}
  IrGenerator.Pc = 1

  IrGenerator:CountPc(State, State.Ir)

  for _, Function in ipairs(State.IrFunctions) do
    IrGenerator.Labels[Function.Label] = IrGenerator.Pc
    IrGenerator:CountPc(State, Function.IrProgram)
  end
end

function IrGenerator:ResolveLabels(State, IrProgram)
  for _, Ir in ipairs(IrProgram) do
    if Ir[1]:find("Jump") or Ir[1] == "NewFunction" then
      local LabelAddress = IrGenerator.Labels[Ir[#Ir]]

      if not LabelAddress then
        Logger:Error(State, "InternalError", "Couldn't resolve label %s", tostring(Ir[#Ir]))
      else
        Ir[#Ir] = LabelAddress
      end
    end
  end
end

function IrGenerator:GenerateIr(State)
  IrGenerator:PushContext(State, true)

  IrGenerator.Ir = {
    [1] = "File",
    [2] = State.File.Name,
  }
  IrGenerator:NewIr(State)

  for _, Ast in ipairs(State.Ast) do
    local ResultRegister = IrGenerator:Generate(State, Ast)

    if ResultRegister then
      IrGenerator:MarkNotUsed(State, ResultRegister)
    end
  end

  IrGenerator:PopContext(State)

  IrGenerator:FindLabels(State)
  IrGenerator:ResolveLabels(State, State.Ir)
  for _, Function in ipairs(State.IrFunctions) do
    IrGenerator:ResolveLabels(State, Function.IrProgram)
  end
end

function IrGenerator:GenerateLuaIr(State)
  State.LuaIr = "::Main::\n"

  local function GenerateBlock(IrProgram)
    for _, Ir in ipairs(IrProgram) do
      local Text = ""
      local Arguments = {}

      for Idx = 2, #Ir do
        local Argument = Ir[Idx]

        if type(Argument) == "string" then
          Arguments[#Arguments + 1] = string.format("%q", Argument)
        else
          Arguments[#Arguments + 1] = tostring(Argument)
        end
      end

      Text = string.format("  %s(%s)", Ir[1], table.concat(Arguments, ", "))
      State.LuaIr = State.LuaIr .. Text .. "\n"
    end
  end

  GenerateBlock(State.Ir)

  for _, Function in ipairs(State.IrFunctions) do
    State.LuaIr = State.LuaIr .. string.format("\n::Label%d::\n", Function.Label)
    GenerateBlock(Function.IrProgram)
  end
end

return IrGenerator
