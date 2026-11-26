local IrGenerator = {}

function IrGenerator:Reset(State)
  IrGenerator.Program = {}
  IrGenerator.Pc = 0

  State.Ir = {}
end

function IrGenerator:NewIr(State)
  local Ir = IrGenerator.Ir
  table.insert(IrGenerator.Program, Ir)

  IrGenerator.Ir = {}
end

function IrGenerator:Generate(State, Ast, Data)
  IrGenerator.Ir = {
    [1] = "Row",
    [2] = Ast.Row,
  }
  IrGenerator:NewIr(State)

  if false then
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
