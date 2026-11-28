--[[
IrGenerator:
  Generate Function Call: Implemented
  Generate Variable Assignment: Implemented
  Generate Local Statement: Partially Implemented -- TODO: Need to check if this TODO is correct
  Generate Function Declaration: Implemented
  Generate Return: Not Implemented
  Generate Break: Not Implemented
  Generate If: Implemented
  Generate While: Implemented
  Generate Expression: Implemented
  Generate Binary Expression: Implemented
  Generate Unary Expression: Implemented
  Generate Identifier: Implemented
  Generate Number Literal: Implemented
  Generate String Literal: Implemented
  Generate Boolean Literal: Implemented
  Generate Nil Literal: Not Implemented
  Generate Table Constructor: Not Implemented
  Generate Table Indexing: Not Implemented
  Generate Member Access: Not Implemented
  Generate Anonymous Function: Not Implemented

TODO: Add local registers
]]

local IrGenerator = {}
local LuaIrGenerator = {}
local Logger = _G.Logger

local Isa = {
  ["Load.Constant"] = {
    Arguments = {
      { Name = "Constant", Type = "Constant" },
      { Name = "Result", Type = "Register" },
    },
  },
  ["Load.Number"] = {
    Arguments = {
      { Name = "Number", Type = "Number" },
      { Name = "Result", Type = "Register" },
    },
  },
  ["Load.Boolean"] = {
    Arguments = {
      { Name = "Boolean", Type = "Boolean" },
      { Name = "Result", Type = "Register" },
    },
  },
  ["Declaration.Function"] = {
    Arguments = {
      { Name = "Label", Type = "Label" },
      { Name = "Name", Type = "Symbol" },
    },
  },
  ["Push"] = {
    Arguments = {
      { Name = "Source", Type = "Register" },
    },
  },
  ["Pop"] = {
    Arguments = {
      { Name = "Result", Type = "Register" },
    },
  },
  ["Call"] = {
    Arguments = {
      { Name = "Function", Type = "Register" },
    },
  },
  ["Move"] = {
    Arguments = {
      { Name = "Source", Type = "Register" },
      { Name = "Destination", Type = "Register" },
    },
  },
  ["Jump.True"] = {
    Arguments = {
      { Name = "Source", Type = "Register" },
      { Name = "Destination", Type = "Label" },
    },
  },
  ["Jump.False"] = {
    Arguments = {
      { Name = "Source", Type = "Register" },
      { Name = "Destination", Type = "Label" },
    },
  },
  ["Jump.Always"] = {
    Arguments = {
      { Name = "Destination", Type = "Label" },
    },
  },
}

local BinaryOperations = {
  "Unknown",
  "Add",
  "Subtract",
  "Multiply",
  "Divide",
  "FloorDivide",
  "Modulo",
  "Power",
  "BitwiseAnd",
  "BitwiseOr",
  "BitwiseXor",
  "ShiftLeft",
  "ShiftRight",
  "Concatenate",
  "Equal",
  "NotEqual",
  "LessThan",
  "LessThanOrEqual",
  "GreaterThan",
  "GreaterThanOrEqual",
}

for Id, Name in ipairs(BinaryOperations) do
  Isa["Any." .. Name] = {
    Arguments = {
      { Name = "Left", Type = "Register" },
      { Name = "Right", Type = "Register" },
      { Name = "Result", Type = "Register" },
    },
  }
end

local UnaryOperations = {
  "BitwiseNot",
  "Negate",
  "Length",
  "Not",
}

for Id, Name in ipairs(UnaryOperations) do
  Isa["Any." .. Name] = {
    Arguments = {
      { Name = "Value", Type = "Register" },
      { Name = "Result", Type = "Register" },
    },
  }
end

function IrGenerator:Reset(State)
  IrGenerator.Program = {}
  IrGenerator.Constants = {}
  IrGenerator.Pc = 0
  IrGenerator.Label = 0
  IrGenerator.NextSymbolId = 1
  IrGenerator.Registers = {}
  IrGenerator.Scopes = {}

  for Idx = 1, 256 do
    IrGenerator.Registers[Idx] = false
  end

  State.Ir = {}
end

function IrGenerator:NewIr(State)
  local Ir = IrGenerator.Ir
  Ir[0] = IrGenerator.Label
  table.insert(IrGenerator.Program, Ir)

  IrGenerator.Ir = {}
end

function IrGenerator:AddConstant(Value)
  for Idx, Constant in pairs(IrGenerator.Constants) do
    if Constant == Value then
      return Idx
    end
  end

  local ConstantId = #IrGenerator.Constants + 1
  IrGenerator.Constants[ConstantId] = Value
  return ConstantId
end

function IrGenerator:AllocateRegister(State)
  for Register, Used in pairs(IrGenerator.Registers) do
    if Used == false then
      IrGenerator.Registers[Register] = true
      return Register
    end
  end
end

function IrGenerator:MarkRegisterNotUsed(State, Register)
  for Idx = #IrGenerator.Scopes, 1, -1 do
    local Scope = IrGenerator.Scopes[Idx]

    for _, VariableRegister in pairs(Scope) do
      if VariableRegister == Register then
        return
      end
    end
  end

  IrGenerator.Registers[Register] = false
end

function IrGenerator:DefineVariable(State, Variable, Value)
  local Scope = IrGenerator.Scopes[#IrGenerator.Scopes]
  local VariableRegister = IrGenerator:AllocateRegister(State)
  Scope[Variable.Name] = VariableRegister

  if Value then
    local ValueRegister = IrGenerator:Generate(State, Value)

    IrGenerator.Ir = {
      [1] = "Move",
      [2] = ValueRegister,
      [3] = VariableRegister,
    }
    IrGenerator:NewIr(State)
    IrGenerator:MarkRegisterNotUsed(State, ValueRegister)
  end

  return VariableRegister
end

function IrGenerator:NewSymbol(State)
  local SymbolId = IrGenerator.NextSymbolId
  IrGenerator.NextSymbolId = IrGenerator.NextSymbolId + 1
  return SymbolId
end

function IrGenerator:GenerateBody(State, Body, Label)
  local PreviousLabel = IrGenerator.Label
  IrGenerator.Label = Label

  for _, Ast in ipairs(Body) do
    IrGenerator:Generate(State, Ast)
  end

  IrGenerator.Label = PreviousLabel
end

function IrGenerator:GenerateFunction(State, Ast)
  local FunctionLabel = IrGenerator:NewSymbol(State)

  IrGenerator.Ir = {
    [1] = "Declaration.Function",
    [2] = FunctionLabel,
    [3] = Ast.Name.Name,
  }
  IrGenerator:NewIr(State)

  local PreviousLabel = IrGenerator.Label
  IrGenerator.Label = FunctionLabel

  local Scope = IrGenerator.Scopes[#IrGenerator.Scopes]
  for _, Argument in pairs(Ast.Arguments) do
    local ArgumentRegister = IrGenerator:DefineVariable(State, Ast.Name)

    IrGenerator.Ir = {
      [1] = "Pop",
      [2] = ArgumentRegister,
    }
    IrGenerator:NewIr(State)
  end

  IrGenerator:GenerateBody(State, Ast.Body, FunctionLabel)

  IrGenerator.Label = PreviousLabel
end

function IrGenerator:GenerateFunctionCall(State, Ast)
  -- TODO: Use jump when function is already definied in scope

  local FunctionName = IrGenerator:Generate(State, Ast.Name)

  for _, Argument in ipairs(Ast.Arguments) do
    local ArgumentRegister = IrGenerator:Generate(State, Argument)
    IrGenerator.Ir = {
      [1] = "Push",
      [2] = ArgumentRegister,
    }
    IrGenerator:NewIr(State)
    IrGenerator:MarkRegisterNotUsed(State, ArgumentRegister)
  end

  IrGenerator.Ir = {
    [1] = "Call",
    [2] = FunctionName,
  }
  IrGenerator:NewIr(State)
  IrGenerator:MarkRegisterNotUsed(State, FunctionName)
end

function IrGenerator:GenerateIdentifier(State, Ast)
  for Idx = #IrGenerator.Scopes, 1, -1 do
    local Scope = IrGenerator.Scopes[Idx]

    for Variable, Register in pairs(Scope) do
      if Variable == Ast.Name then
        return Register
      end
    end
  end

  local Constant = IrGenerator:AddConstant(Ast.Name)
  local ResultRegister = IrGenerator:AllocateRegister(State)
  IrGenerator.Ir = {
    [1] = "Load.Constant",
    [2] = Constant,
    [3] = ResultRegister,
  }
  IrGenerator:NewIr(State)

  return ResultRegister
end

function IrGenerator:GenerateString(State, Ast)
  local Constant = IrGenerator:AddConstant(Ast.Value)
  local ResultRegister = IrGenerator:AllocateRegister(State)
  IrGenerator.Ir = {
    [1] = "Load.Constant",
    [2] = Constant,
    [3] = ResultRegister,
  }
  IrGenerator:NewIr(State)

  return ResultRegister
end

function IrGenerator:GenerateBinary(State, Ast)
  local ResultRegister = IrGenerator:AllocateRegister(State)
  local LeftRegister = IrGenerator:Generate(State, Ast.Left)
  local RightRegister = IrGenerator:Generate(State, Ast.Right)

  local Operators = {
    ["+"] = "Add",
    ["-"] = "Subtract",
    ["*"] = "Multiply",
    ["/"] = "Divide",
    ["//"] = "FloorDivide",
    ["%"] = "Modulo",
    ["^"] = "Power",
    ["&"] = "BitwiseAnd",
    ["|"] = "BitwiseOr",
    ["~"] = "BitwiseXor",
    ["<<"] = "ShiftLeft",
    [">>"] = "ShiftRight",
    [".."] = "Concatenate",
    ["=="] = "Equal",
    ["~="] = "NotEqual",
    ["<"] = "LessThan",
    ["<="] = "LessThanOrEqual",
    [">"] = "GreaterThan",
    [">="] = "GreaterThanOrEqual",
  }
  local Opcode = Operators[Ast.Operator] or "Unknown"

  IrGenerator.Ir = {
    [1] = "Any." .. Opcode,
    [2] = LeftRegister,
    [3] = RightRegister,
    [4] = ResultRegister,
  }
  IrGenerator:NewIr(State)
  IrGenerator:MarkRegisterNotUsed(State, LeftRegister)
  IrGenerator:MarkRegisterNotUsed(State, RightRegister)

  return ResultRegister
end

function IrGenerator:GenerateUnary(State, Ast)
  local ResultRegister = IrGenerator:AllocateRegister(State)
  local OperandRegister = IrGenerator:Generate(State, Ast.Operand)

  local Operators = {
    ["not"] = "Not",
    ["-"] = "Negate",
    ["~"] = "BitwiseNot",
    ["#"] = "Length",
  }
  local Opcode = Operators[Ast.Operator] or "Unknown"

  IrGenerator.Ir = {
    [1] = "Any." .. Opcode,
    [2] = OperandRegister,
    [3] = ResultRegister,
  }
  IrGenerator:NewIr(State)
  IrGenerator:MarkRegisterNotUsed(State, OperandRegister)

  return ResultRegister
end

function IrGenerator:GenerateNumber(State, Ast)
  local ResultRegister = IrGenerator:AllocateRegister(State)
  IrGenerator.Ir = {
    [1] = "Load.Number",
    [2] = Ast.Value,
    [3] = ResultRegister,
  }
  IrGenerator:NewIr(State)

  return ResultRegister
end

function IrGenerator:GenerateBoolean(State, Ast)
  local ResultRegister = IrGenerator:AllocateRegister(State)
  IrGenerator.Ir = {
    [1] = "Load.Boolean",
    [2] = Ast.Value,
    [3] = ResultRegister,
  }
  IrGenerator:NewIr(State)

  return ResultRegister
end

function IrGenerator:GenerateVariableDeclaration(State, Ast)
  local Scope = IrGenerator.Scopes[#IrGenerator.Scopes]

  for Idx, Variable in pairs(Ast.Name) do
    local Value = Ast.Value[((Idx - 1) % #Ast.Value) + 1]
    IrGenerator:DefineVariable(State, Variable, Value)
  end
end

function IrGenerator:GenerateVariableAssign(State, Ast)
  for Idx, Variable in pairs(Ast.Name) do
    local Value = Ast.Value[((Idx - 1) % #Ast.Value) + 1]

    local VariableRegister = IrGenerator:Generate(State, Variable)
    local ValueRegister = IrGenerator:Generate(State, Value)

    IrGenerator.Ir = {
      [1] = "Move",
      [2] = ValueRegister,
      [3] = VariableRegister,
    }
    IrGenerator:NewIr(State)
    IrGenerator:MarkRegisterNotUsed(State, ValueRegister)
    IrGenerator:MarkRegisterNotUsed(State, VariableRegister)
  end
end

function IrGenerator:GenerateGroup(State, Ast)
  return IrGenerator:Generate(State, Ast.Expression)
end

function IrGenerator:GenerateIf(State, Ast)
  local BodyLabel = IrGenerator:NewSymbol(State)
  local ElseLabel

  local ConditionRegister = IrGenerator:Generate(State, Ast.Condition)

  if Ast.Else then
    ElseLabel = IrGenerator:NewSymbol(State)

    IrGenerator.Ir = {
      [1] = "Jump.False",
      [2] = ConditionRegister,
      [3] = ElseLabel,
    }
    IrGenerator:NewIr(State)
  end

  IrGenerator.Ir = {
    [1] = "Jump.True",
    [2] = ConditionRegister,
    [3] = BodyLabel,
  }
  IrGenerator:NewIr(State)

  IrGenerator:MarkRegisterNotUsed(State, ConditionRegister)

  local AfterLabel = IrGenerator:NewSymbol(State)
  local PreviousLabel = IrGenerator.Label

  IrGenerator:GenerateBody(State, Ast.Body, BodyLabel)
  IrGenerator.Label = BodyLabel
  IrGenerator.Ir = {
    [1] = "Jump.Always",
    [2] = AfterLabel,
  }
  IrGenerator:NewIr(State)

  IrGenerator.Label = PreviousLabel

  if Ast.Else then
    IrGenerator:GenerateBody(State, Ast.Else, ElseLabel)
    IrGenerator.Label = ElseLabel
    IrGenerator.Ir = {
      [1] = "Jump.Always",
      [2] = AfterLabel,
    }
    IrGenerator:NewIr(State)
  end

  IrGenerator.Label = AfterLabel
end

function IrGenerator:GenerateWhile(State, Ast)
  local ConditionLabel = IrGenerator:NewSymbol(State)
  local BodyLabel = IrGenerator:NewSymbol(State)
  local AfterLabel = IrGenerator:NewSymbol(State)

  IrGenerator.Ir = {
    [1] = "Jump.Always",
    [2] = ConditionLabel,
  }
  IrGenerator:NewIr(State)

  IrGenerator.Label = ConditionLabel

  local ConditionRegister = IrGenerator:Generate(State, Ast.Condition)

  IrGenerator.Ir = {
    [1] = "Jump.True",
    [2] = ConditionRegister,
    [3] = BodyLabel,
  }
  IrGenerator:NewIr(State)

  IrGenerator.Ir = {
    [1] = "Jump.Always",
    [2] = AfterLabel,
  }
  IrGenerator:NewIr(State)

  local PreviousLabel = IrGenerator.Label

  IrGenerator:GenerateBody(State, Ast.Body, BodyLabel)
  IrGenerator.Label = BodyLabel
  IrGenerator.Ir = {
    [1] = "Jump.Always",
    [2] = ConditionLabel,
  }
  IrGenerator:NewIr(State)

  IrGenerator.Label = AfterLabel
end

function IrGenerator:Generate(State, Ast)
  if Ast.Row then
    IrGenerator.Ir = {
      [1] = "Row",
      [2] = Ast.Row,
    }
    IrGenerator:NewIr(State)
  end

  if Ast.Kind == "String" then
    return IrGenerator:GenerateString(State, Ast)
  elseif Ast.Kind == "Number" then
    return IrGenerator:GenerateNumber(State, Ast)
  elseif Ast.Kind == "Boolean" then
    return IrGenerator:GenerateBoolean(State, Ast)
  elseif Ast.Kind == "Binary" then
    return IrGenerator:GenerateBinary(State, Ast)
  elseif Ast.Kind == "Unary" then
    return IrGenerator:GenerateUnary(State, Ast)
  elseif Ast.Kind == "Group" then
    return IrGenerator:GenerateGroup(State, Ast)
  elseif Ast.Kind == "Identifier" then
    return IrGenerator:GenerateIdentifier(State, Ast)
  elseif Ast.Kind == "FunctionDeclaration" then
    return IrGenerator:GenerateFunction(State, Ast)
  elseif Ast.Kind == "FunctionCall" then
    return IrGenerator:GenerateFunctionCall(State, Ast)
  elseif Ast.Kind == "VariableDeclaration" then
    return IrGenerator:GenerateVariableDeclaration(State, Ast)
  elseif Ast.Kind == "VariableAssign" then
    return IrGenerator:GenerateVariableAssign(State, Ast)
  elseif Ast.Kind == "If" then
    return IrGenerator:GenerateIf(State, Ast)
  elseif Ast.Kind == "While" then
    return IrGenerator:GenerateWhile(State, Ast)
  else
    Logger:Error(
      State,
      "InternalError",
      "Couldn't find a handler for %s when generating Ir for it",
      Ast.Kind or (type(Ast) .. " (type)")
    )
  end
end

function IrGenerator:GenerateIr(State)
  IrGenerator.Ir = {
    [1] = "File",
    [2] = State.File.Name,
  }
  IrGenerator:NewIr(State)

  IrGenerator.Label = IrGenerator:NewSymbol(State)
  IrGenerator.Ir = {
    [1] = "Declaration.Function",
    [2] = IrGenerator.Label,
    [3] = "_start",
  }
  IrGenerator:NewIr(State)

  table.insert(IrGenerator.Scopes, {})

  for _, Ast in ipairs(State.Ast) do
    local ResultRegister = IrGenerator:Generate(State, Ast)

    if ResultRegister then
      IrGenerator:MarkRegisterNotUsed(State, ResultRegister)
    end
  end

  State.Program = {
    Ir = IrGenerator.Program,
    Constants = IrGenerator.Constants,
  }
end

function LuaIrGenerator:GenerateSymbol(Symbol)
  return Symbol
end

function LuaIrGenerator:GenerateArguments(Ir)
  local Arguments = {}

  local Opcode = Ir[1]
  local IsaCommand = Isa[Opcode]
  local IsaArguments = IsaCommand.Arguments

  for Idx = 2, #Ir do
    local IsaArgument = IsaArguments[Idx - 1]
    local Argument = Ir[Idx]
    local Prefix = ""

    if IsaArgument.Type == "Register" then
      Prefix = "%"
    elseif IsaArgument.Type == "Constant" then
      Prefix = "$"
    elseif IsaArgument.Type == "Label" then
      Prefix = "@"
    end

    if type(Argument) == "string" then
      Arguments[#Arguments + 1] = Prefix .. string.format("%q", Argument)
    else
      Arguments[#Arguments + 1] = Prefix .. tostring(Argument)
    end
  end

  return table.concat(Arguments, ", ")
end

function LuaIrGenerator:GenerateFunction(Symbols, Label)
  local FunctionName = LuaIrGenerator:GenerateSymbol(Symbols[Label])
  if FunctionName == nil then
    FunctionName = "__anonymous_block_" .. Label
  end

  return string.format("function %s()", FunctionName)
end

function LuaIrGenerator:GenerateCommand(Ir, Indent)
  local IndentString = ("  "):rep(Indent)
  local Arguments = LuaIrGenerator:GenerateArguments(Ir)

  return string.format("%s%s %s", IndentString, Ir[1]:lower(), Arguments)
end

function LuaIrGenerator:Generate(State)
  local Output = {}
  local Symbols = {}
  local LastLabel = 0

  for Idx, Constant in pairs(State.Program.Constants) do
    Output[#Output + 1] = string.format("constant %d, %q", Idx, Constant)
  end

  Output[#Output + 1] = ""

  for _, Ir in ipairs(State.Program.Ir) do
    if Ir[1]:find("Declaration") then
      Symbols[Ir[2]] = Ir[3]
    end
  end

  for _, Ir in ipairs(State.Program.Ir) do
    local Kind = Ir[1]

    if Kind ~= "File" and Kind ~= "Row" and (not Kind:find("Declaration")) then
      local Label = Ir[0]
      if Label ~= LastLabel then
        if LastLabel ~= 0 then
          Output[#Output + 1] = "end\n"
        end

        if Label ~= 0 then
          Output[#Output + 1] = LuaIrGenerator:GenerateFunction(Symbols, Label)
        end

        LastLabel = Label
      end

      local Indent = 0
      if Label ~= 0 then
        Indent = 1
      end

      Output[#Output + 1] = LuaIrGenerator:GenerateCommand(Ir, Indent)
    end
  end

  if LastLabel ~= 0 then
    Output[#Output + 1] = "end"
  end

  State.LuaIr = table.concat(Output, "\n")
end

return { IrGenerator = IrGenerator, LuaIrGenerator = LuaIrGenerator }
