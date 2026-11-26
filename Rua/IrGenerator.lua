local IrGenerator = {}
local Logger = _G.Logger

function IrGenerator:Reset(State)
  IrGenerator.Program = {}
  IrGenerator.Pc = 0
  IrGenerator.Label = 0
  IrGenerator.NextLabelId = 1
  IrGenerator.Registers = {}

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

function IrGenerator:AllocateRegister()
  for Register, Used in pairs(IrGenerator.Registers) do
    if Used == true then
      break
    end

    return Register
  end
end

function IrGenerator:MarkRegisterNotUsed(Register)
  IrGenerator[Register] = false
end

function IrGenerator:NewLabel()
  local LabeId = IrGenerator.NextLabelId
  IrGenerator.NextLabelId = IrGenerator.NextLabelId + 1
  return LabeId
end

function IrGenerator:GenerateBody(State, Body, Label)
  IrGenerator.Label = Label

  for _, Ast in ipairs(Body) do
    IrGenerator:Generate(State, Ast)
  end
end

function IrGenerator:GenerateFunction(State, Ast)
  local FunctionLabel = IrGenerator:NewLabel()
  IrGenerator:GenerateBody(State, Ast.Body, FunctionLabel)
end

function IrGenerator:GenerateFunctionCall(State, Ast)
  -- TODO: Use jump when function is already definied in scope
  -- TODO: Implement arguments

  local FunctionName = IrGenerator:Generate(State, Ast.Name)
  IrGenerator.Ir = {
    [1] = "Call",
    [2] = FunctionName,
  }
  IrGenerator:NewIr(State)
  IrGenerator:MarkRegisterNotUsed(FunctionName)
end

function IrGenerator:GenerateIdentifier(State, Ast)
  -- TODO: Add constant pool

  local ResultRegister = IrGenerator:AllocateRegister()
  IrGenerator.Ir = {
    [1] = "Constant",
    [2] = Ast.Name,
    [3] = ResultRegister,
  }
  IrGenerator:NewIr(State)

  return ResultRegister
end

function IrGenerator:Generate(State, Ast)
  if Ast.Row then
    IrGenerator.Ir = {
      [1] = "Row",
      [2] = Ast.Row,
    }
    IrGenerator:NewIr(State)
  end

  if Ast.Kind == "Function" then
    return IrGenerator:GenerateFunction(State, Ast)
  elseif Ast.Kind == "FunctionCall" then
    return IrGenerator:GenerateFunctionCall(State, Ast)
  elseif Ast.Kind == "Identifier" then
    return IrGenerator:GenerateIdentifier(State, Ast)
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

  for _, Ast in ipairs(State.Ast) do
    local ResultRegister = IrGenerator:Generate(State, Ast)

    if ResultRegister then
      IrGenerator:MarkNotUsed(State, ResultRegister)
    end
  end

  State.IrProgram = IrGenerator.Program
end

function IrGenerator:GenerateLuaIr(State)
  State.LuaIr = "::Main::\n"

  for _, Ir in ipairs(State.IrProgram) do
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

return IrGenerator
