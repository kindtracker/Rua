local VmDebugger = {}

local function FormatValue(Value)
  if type(Value) == "string" or type(Value) == "number" then
    return string.format("%q", Value)
  end

  return tostring(Value)
end

local function PrintTable(Table, Level)
  Level = Level or 0

  io.write(string.rep("  ", Level) .. "{\n")
  for Key, Value in pairs(Table) do
    if type(Value) == "table" then
      io.write(string.rep("  ", Level + 1) .. string.format("[%q] = {", Key))
      PrintTable(Value, Level + 1)
    else
      io.write(string.rep("  ", Level + 1) .. string.format("[%s] = %s", FormatValue(Key), FormatValue(Value)))
    end
    io.write(",\n")
  end

  io.write(string.rep("  ", Level) .. "}")
end

local function VmRun(State, Vm)
  local Result

  while State.Vm.Pc <= #State.Bytecode.Program do
    State.Vm.InstructionPc = State.Vm.Pc

    Vm:Decode(State)
    if State.Stop then
      return
    end

    VmDebugger:BeforeInstruction(State)
    if State.Stop then
      return
    end

    Result = Vm:Execute(State)
    if State.Stop then
      return
    end
  end

  return Result
end

function VmDebugger:Initialize(State, Rua)
  Rua.Vm.Run = function(_, CurrentState)
    return VmRun(CurrentState, Rua.Vm)
  end

  State.VmDebugger = {
    Enabled = true,
    Paused = false,
    Stepping = false,
    Breakpoints = {},
  }
end

function VmDebugger:AddBreakpoint(State, Address)
  State.VmDebugger.Breakpoints[Address] = true
end

function VmDebugger:RemoveBreakpoint(State, Address)
  State.VmDebugger.Breakpoints[Address] = nil
end

function VmDebugger:PrintValue(Value)
  if Value == nil then
    return "nil"
  end

  if type(Value) == "table" then
    if Value.Name and Value.Function then
      return "<Function " .. Value.Name .. ">"
    end

    return "<Table>"
  end

  return string.format("%q", Value)
end

function VmDebugger:PrintRegisters(State)
  for Index, Register in ipairs(State.Vm.Registers) do
    if Register.Type ~= "Nil" then
      io.write(string.format("Register%-3d %-10s %s\n", Index, Register.Type, self:PrintValue(Register.Value)))
    end
  end
end

function VmDebugger:PrintStack(State)
  for Index, Value in ipairs(State.Vm.Stack) do
    io.write(string.format("[%d] %s: %s\n", Index, Value.Type, self:PrintValue(Value.Value)))
  end
end

function VmDebugger:PrintVariables(State)
  for Name, Value in pairs(State.Vm.Variables) do
    io.write(string.format("%s = %s (%s)\n", Name, self:PrintValue(Value.Value), Value.Type))
  end
end

function VmDebugger:PrintCallStack(State)
  for Index, Address in ipairs(State.Vm.CallStack) do
    io.write(string.format("[%d] return to address %d\n", Index, Address))
  end
end

function VmDebugger:PrintInstruction(State)
  io.write(string.format("%04d: %s\n", State.Vm.InstructionPc, State.Vm.Opcode or "<Unknown>"))

  for Name, Value in pairs(State.Vm.Arguments or {}) do
    if type(Value) == "table" and Value.Type then
      io.write(string.format("  %s = %s (%s)\n", Name, self:PrintValue(Value.Value), Value.Type))
    else
      io.write(string.format("  %s = %s\n", Name, self:PrintValue(Value)))
    end
  end
end

function VmDebugger:Pause(State)
  local Debug = State.VmDebugger
  Debug.Paused = true

  while Debug.Paused do
    self:PrintInstruction(State)

    Debug.Stepping = true
    Debug.Paused = false

    io.write("(Rua) ")
    local Input = io.read("*l")

    if not Input then
      Debug.Paused = false
      return
    end

    local Command, Argument = Input:match("^(%S+)%s*(.-)%s*$")

    if Command == "Step" then
      Debug.Stepping = true
      Debug.Paused = false
    elseif Command == "Continue" then
      Debug.Stepping = false
      Debug.Paused = false
    elseif Command == "AddBreakPoint" then
      local Address = tonumber(Argument)

      if Address then
        self:AddBreakpoint(State, Address)
        io.write(string.format("Breakpoint added at %d\n", Address))
      else
        io.write("Usage: break <Address>\n")
      end
    elseif Command == "RemoveBreakpoint" then
      local Address = tonumber(Argument)

      if Address then
        self:RemoveBreakpoint(State, Address)
        io.write(string.format("Breakpoint removed at %d\n", Address))
      else
        io.write("Usage: delete <Address>\n")
      end
    elseif Command == "Registers" then
      self:PrintRegisters(State)
    elseif Command == "Stack" then
      self:PrintStack(State)
    elseif Command == "Variables" then
      self:PrintVariables(State)
    elseif Command == "CallStack" then
      self:PrintCallStack(State)
    elseif Command == "Instruction" then
      self:PrintInstruction(State)
    elseif Command == "Quit" then
      State.Stop = true
      Debug.Paused = false
    elseif Command == "Help" then
      io.write("Step                 Execute one instruction\n")
      io.write("Continue             Resume execution\n")
      io.write("AddBreakPoint N      Break at bytecode address N\n")
      io.write("RemoveBreakPoint N   Remove breakpoint N\n")
      io.write("Registers            Show non-nil registers\n")
      io.write("Stack                Show VM stack\n")
      io.write("Variables            Show VM variables\n")
      io.write("CallStack            Show call stack\n")
      io.write("Instruction          Show current instruction\n")
      io.write("Quit                 Stop VM execution\n")
    else
      io.write("Unknown command. Type Help.\n")
    end
  end
end

function VmDebugger:BeforeInstruction(State)
  local Debug = State.VmDebugger

  if not Debug or not Debug.Enabled then
    return
  end

  local Address = State.Vm.InstructionPc

  if Debug.Stepping or Debug.Breakpoints[Address] then
    self:Pause(State)
  end
end

return VmDebugger
