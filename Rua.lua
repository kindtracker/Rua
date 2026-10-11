--[[
  Rua, single-file Lua implementation built in Lua.
  Copyright (C) 2026 Kindtracker

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local Rua = {}

local _

local BaseIdent = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
local BasePunct = "(){}[];,:."
local BaseDigits = "0123456789"
local BaseOperators = "=<>~&|+-*/^%#"
local BaseEscape = ""

local BaseKeywords = {
  "and",
  "break",
  "do",
  "else",
  "elseif",
  "end",
  "for",
  "function",
  "goto",
  "if",
  "in",
  "local",
  "not",
  "or",
  "repeat",
  "return",
  "then",
  "until",
  "while",
}

local ExpressionPrecedence = {
  ["or"] = 1,
  ["and"] = 2,

  ["=="] = 3,
  ["~="] = 3,
  ["<"] = 3,
  [">"] = 3,
  ["<="] = 3,
  [">="] = 3,

  ["|"] = 4,
  ["~"] = 5,
  ["&"] = 6,

  ["<<"] = 7,
  [">>"] = 7,

  [".."] = 8,

  ["+"] = 9,
  ["-"] = 9,

  ["*"] = 10,
  ["/"] = 10,
  ["//"] = 10,
  ["%"] = 10,

  ["^"] = 11,
}

local WhiteSpace = "\n\t\r "

local Ansi = {
  Reset = "\27[0m",
  Yellow = "\27[33m",
  Red = "\27[31m",
  Blue = "\27[38;2;100;200;255m",
}

local function StringHasLetter(String, Letter)
  for Character in String:gmatch(".") do
    if Character == Letter then
      return true
    end
  end

  return false
end

local function TableHasString(Table, StringToSearch)
  for _, String in ipairs(Table) do
    if String == StringToSearch then
      return true
    end
  end

  return false
end

local function PrintTable(Table, Level)
  Level = Level or 0

  io.write(string.rep("  ", Level) .. "{\n")
  for Key, Value in pairs(Table) do
    if type(Value) == "table" then
      io.write(string.rep("  ", Level + 1) .. string.format("[%q] = {", Key))
      PrintTable(Value, Level + 1)
    else
      io.write(string.rep("  ", Level + 1) .. string.format("[%q] = %q", Key, Value))
    end
    io.write(",\n")
  end

  io.write(string.rep("  ", Level) .. "}")
end

local function GetLine(Content, Line)
  local CurrentLine = 1

  for TextLine in Content:gmatch("[^\r\n]*\r?\n?") do
    if TextLine == "" and CurrentLine > Line then
      break
    end

    if CurrentLine == Line then
      return TextLine:gsub("[\r\n]+$", "")
    end

    CurrentLine = CurrentLine + 1
  end

  return ""
end

local function GetWordStartAndFinish(Line, Row)
  local Start = Row
  local Finish = Row

  while Start > 1 and Line:sub(Start - 1, Start - 1):match("[%w_]") do
    Start = Start - 1
  end

  while Finish <= #Line and Line:sub(Finish, Finish):match("[%w_]") do
    Finish = Finish + 1
  end

  return Start, Finish
end

local function HighlightWord(Line, Row)
  local Start, Finish = GetWordStartAndFinish(Line, Row)
  return Line:sub(1, Start - 1) .. Ansi.Red .. Line:sub(Start, Finish - 1) .. Ansi.Reset .. Line:sub(Finish)
end

function Rua.new()
  return {
    FileName = "",
    FileContent = "",
    FileIndex = 0,
    TokenCharacter = "",
    Tokens = {},
    Ast = {},
    TokenIndex = 0,
    CurrentToken = {},
    Line = 1,
    Row = 1,
    Stop = false,
    Ir = {
      Program = {},
      LabelCount = 0,
      Registers = {},
    },
    ShowFaultLine = true,
    Bytecode = {
      Program = "",
      ProgramTable = {},
      Lables = {},
      Isa = {
        Opcodes = {
          Copy = 1,
          CallFromRegister = 2,
          LoadNumber = 3,
          LoadString = 4,
          LoadBoolean = 5,
          GetVariable = 6,
          VariableAssign = 7,
          JumpIfFalseTest = 8,
          Push = 9,
          Pop = 10,
          Test = 11,
          Jump = 12,
          Label = 13,
          Add = 14,
          Sub = 15,
          Mul = 16,
          Div = 17,
          Mod = 18,
          Pow = 19,
          NotEqual = 20,
          Equal = 21,
          EqualOrGreaterThan = 22,
          EqualOrLessThan = 23,
          GreaterThan = 24,
          LessThan = 25,
          NumberAnd = 26,
          NumberOr = 27,
          NumberXor = 28,
          LoadFunction = 29,
          JumpIfFalseRegister = 30,
          JumpIfTrueTest = 31,
          JumpIfTrueRegister = 31,
          Return = 32,
        },

        InstructionArguments = {
          CallFromRegister = {
            [1] = { Type = "RegisterFunction", Name = "FunctionRegister" },
          },

          LoadNumber = {
            [1] = { Type = "Number", Name = "Number" },
            [2] = { Type = "Register", Name = "ResultRegister" },
          },

          LoadString = {
            [1] = { Type = "String", Name = "String" },
            [2] = { Type = "Register", Name = "ResultRegister" },
          },

          LoadBoolean = {
            [1] = { Type = "Boolean", Name = "Boolean" },
            [2] = { Type = "Register", Name = "ResultRegister" },
          },

          GetVariable = {
            [1] = { Type = "RegisterString", Name = "VariableName" },
            [2] = { Type = "Register", Name = "VariableRegister" },
          },

          VariableAssign = {
            [1] = { Type = "RegisterString", Name = "VariableName" },
            [2] = { Type = "Register", Name = "VariableRegister" },
          },

          Push = {
            [1] = { Type = "Register", Name = "FromRegister" },
          },

          Pop = {
            [1] = { Type = "Register", Name = "ResultRegister" },
          },

          Test = {
            [1] = { Type = "Register", Name = "CheckRegister" },
          },

          Jump = {
            [1] = { Type = "Label", Name = "TargetAddress" },
          },

          Label = {
            [1] = { Type = "Label", Name = "TargetAddress" },
          },

          Add = {
            [1] = { Type = "Register", Name = "LeftRegister" },
            [2] = { Type = "Register", Name = "RightRegister" },
            [3] = { Type = "Register", Name = "ResultRegister" },
          },

          Sub = {
            [1] = { Type = "Register", Name = "LeftRegister" },
            [2] = { Type = "Register", Name = "RightRegister" },
            [3] = { Type = "Register", Name = "ResultRegister" },
          },

          Mul = {
            [1] = { Type = "Register", Name = "LeftRegister" },
            [2] = { Type = "Register", Name = "RightRegister" },
            [3] = { Type = "Register", Name = "ResultRegister" },
          },

          Div = {
            [1] = { Type = "Register", Name = "LeftRegister" },
            [2] = { Type = "Register", Name = "RightRegister" },
            [3] = { Type = "Register", Name = "ResultRegister" },
          },

          Mod = {
            [1] = { Type = "Register", Name = "LeftRegister" },
            [2] = { Type = "Register", Name = "RightRegister" },
            [3] = { Type = "Register", Name = "ResultRegister" },
          },

          Pow = {
            [1] = { Type = "Register", Name = "LeftRegister" },
            [2] = { Type = "Register", Name = "RightRegister" },
            [3] = { Type = "Register", Name = "ResultRegister" },
          },

          NotEqual = {
            [1] = { Type = "Register", Name = "LeftRegister" },
            [2] = { Type = "Register", Name = "RightRegister" },
            [3] = { Type = "Register", Name = "ResultRegister" },
          },

          Equal = {
            [1] = { Type = "Register", Name = "LeftRegister" },
            [2] = { Type = "Register", Name = "RightRegister" },
            [3] = { Type = "Register", Name = "ResultRegister" },
          },

          EqualOrGreaterThan = {
            [1] = { Type = "Register", Name = "LeftRegister" },
            [2] = { Type = "Register", Name = "RightRegister" },
            [3] = { Type = "Register", Name = "ResultRegister" },
          },

          EqualOrLessThan = {
            [1] = { Type = "Register", Name = "LeftRegister" },
            [2] = { Type = "Register", Name = "RightRegister" },
            [3] = { Type = "Register", Name = "ResultRegister" },
          },

          GreaterThan = {
            [1] = { Type = "Register", Name = "LeftRegister" },
            [2] = { Type = "Register", Name = "RightRegister" },
            [3] = { Type = "Register", Name = "ResultRegister" },
          },

          LessThan = {
            [1] = { Type = "Register", Name = "LeftRegister" },
            [2] = { Type = "Register", Name = "RightRegister" },
            [3] = { Type = "Register", Name = "ResultRegister" },
          },

          NumberAnd = {
            [1] = { Type = "Register", Name = "LeftRegister" },
            [2] = { Type = "Register", Name = "RightRegister" },
            [3] = { Type = "Register", Name = "ResultRegister" },
          },

          NumberOr = {
            [1] = { Type = "Register", Name = "LeftRegister" },
            [2] = { Type = "Register", Name = "RightRegister" },
            [3] = { Type = "Register", Name = "ResultRegister" },
          },

          NumberXor = {
            [1] = { Type = "Register", Name = "LeftRegister" },
            [2] = { Type = "Register", Name = "RightRegister" },
            [3] = { Type = "Register", Name = "ResultRegister" },
          },

          LoadFunction = {
            [1] = { Type = "Label", Name = "FunctionAddress" },
            [2] = { Type = "Register", Name = "FunctionName" },
            [3] = { Type = "Number", Name = "FunctionArgumentCount" },
          },

          JumpIfFalseTest = {
            [1] = { Type = "Label", Name = "ToAddress" },
          },

          JumpIfFalseRegister = {
            [1] = { Type = "Label", Name = "ToAddress" },
            [2] = { Type = "Register", Name = "CheckRegister" },
          },

          JumpIfTrueTest = {
            [1] = { Type = "Label", Name = "ToAddress" },
          },

          JumpIfTrueRegister = {
            [1] = { Type = "Label", Name = "ToAddress" },
            [2] = { Type = "Register", Name = "CheckRegister" },
          },

          Return = {},

          Copy = {
            [1] = { Type = "Register", Name = "SourceRegister" },
            [2] = { Type = "Register", Name = "DestinationRegister" },
          },
        },

        NumericOpcodes = {
          Add = true,
          Sub = true,
          Mul = true,
          Div = true,
          Mod = true,
          Pow = true,
          NumberAnd = true,
          NumberOr = true,
          NumberXor = true,
        },

        ComparisonOpcodes = {
          NotEqual = true,
          Equal = true,
          EqualOrGreaterThan = true,
          EqualOrLessThan = true,
          GreaterThan = true,
          LessThan = true,
        },
      },
    },

    Vm = {
      Pc = 1,
      Registers = {},
      Stack = {},
      Frames = {},
      CallStack = {},
      Environment = {},
      Arguments = {},
      Opcode = "",
      TestFailed = false,
    },

    Lua = { Program = "" },
  }
end

function Rua:Run(State, FileName)
  State.FileName = FileName
  State.FileContent = io.open(FileName, "r"):read("*a")

  Rua:Tokenize(State)
  if State.Stop then
    return
  end

  if Rua.DevMode then
    PrintTable(State.Tokens)
    io.write("\n")
  end

  Rua:Parse(State)
  if State.Stop then
    return
  end

  if Rua.DevMode then
    PrintTable(State.Ast)
    io.write("\n")
  end

  State.ShowFaultLine = false

  Rua:GenerateIr(State)
  if State.Stop then
    return
  end

  if Rua.DevMode then
    PrintTable(State.Ir.Program)
    io.write("\n")
  end

  Rua:GenerateLua(State)
  if State.Stop then
    return
  end

  if Rua.DevMode then
    io.open("Dev.lua", "w"):write(State.Lua.Program)
  end

  Rua:GenerateBytecode(State)
  if State.Stop then
    return
  end

  if Rua.DevMode then
    io.open("Dev.rua", "wb"):write(State.Bytecode.Program)
  end

  Rua:Execute(State)
end

local Logger = {}

function Logger:Error(State, ...)
  local SourceLine = GetLine(State.FileContent, State.Line)
  local HighlightedWord = HighlightWord(SourceLine, State.Row)

  local WordStart, WordFinish = GetWordStartAndFinish(SourceLine, State.Row)
  local WordLength = WordFinish - WordStart

  local Format = "%sError:%s %s\n"
  if State.ShowFaultLine then
    Format = "%s:%d:%d: " .. Format
    Format = Format .. " %s\n%s%s^%s%s\n"
  else
    Format = "%s: " .. Format
  end

  if State.ShowFaultLine then
    io.write(
      string.format(
        Format,
        State.FileName,
        State.Line,
        State.Row,
        Ansi.Red,
        Ansi.Reset,
        string.format(...),
        HighlightedWord,
        string.rep(" ", WordStart),
        Ansi.Red,
        string.rep("~", WordLength - 1),
        Ansi.Reset
      )
    )
  else
    io.write(string.format(Format, State.FileName, Ansi.Red, Ansi.Reset, string.format(...)))
  end

  State.Stop = true

  if Rua.DevMode then
    io.write(
      string.format(
        "%sLua:%s traceback:\n%s\n",
        Ansi.Blue,
        Ansi.Reset,
        debug.traceback():gsub("stack traceback:\n", ""):gsub("	", "   ")
      )
    )
  end
end

local Tokenizer = {}

function Tokenizer:Advance(State)
  local Character = State.TokenCharacter

  State.FileIndex = State.FileIndex + 1

  if Character == "\n" then
    State.Line = State.Line + 1
    State.Row = 1
  else
    State.Row = State.Row + 1
  end

  State.TokenCharacter = State.FileContent:sub(State.FileIndex, State.FileIndex)

  return Character
end

function Tokenizer:Initialize(State)
  State.FileIndex = 0
  State.Line = 1
  State.Row = 1
  State.TokenCharacter = State.FileContent:sub(1, 1)
end

function Tokenizer:AddToken(State, Kind, Value)
  table.insert(State.Tokens, { Kind = Kind, Value = Value, Line = State.Line, Row = State.Row })
end

function Rua:Tokenize(State)
  Tokenizer:Initialize(State)

  while true do
    if State.Stop then
      break
    end

    if StringHasLetter(BaseIdent, State.TokenCharacter) then
      local StartIndex = State.FileIndex
      local StartRow = State.Row

      while StringHasLetter(BaseIdent, State.TokenCharacter) do
        Tokenizer:Advance(State)
      end
      local EndRow = State.Row

      local Ident = State.FileContent:sub(StartIndex, State.FileIndex - 1)
      local IsKeyword = TableHasString(BaseKeywords, Ident)

      State.Row = StartRow
      Tokenizer:AddToken(State, IsKeyword and "Keyword" or "Ident", Ident)
      State.Row = EndRow
    elseif StringHasLetter(BasePunct, State.TokenCharacter) then
      local Punct = Tokenizer:Advance(State)

      State.Row = State.Row - 1
      Tokenizer:AddToken(State, "Punct", Punct)
      State.Row = State.Row + 1
    elseif StringHasLetter(BaseOperators, State.TokenCharacter) then
      local Operator = Tokenizer:Advance(State)
      local IsComment = false
      local IsMultipleLineComment = false

      if Operator == "-" then
        if State.TokenCharacter == "-" then
          IsComment = true
          Tokenizer:Advance(State)
          if State.TokenCharacter == "[" then
            Tokenizer:Advance(State)
            if State.TokenCharacter == "[" then
              IsMultipleLineComment = true
            end
          end

          while true do
            Tokenizer:Advance(State)
            if IsMultipleLineComment then
              if State.TokenCharacter == "]" then
                Tokenizer:Advance(State)
                if State.TokenCharacter == "]" then
                  Tokenizer:Advance(State)
                  break
                end
              end
            elseif State.TokenCharacter == "\n" then
              break
            end
          end
        end
      elseif Operator == "=" or Operator == "~" or Operator == ">" or Operator == "<" or Operator == "|" then
        if State.TokenCharacter == "=" then
          Operator = Operator .. "="
          Tokenizer:Advance(State)
        elseif State.TokenCharacter == ">" or Operator.TokenCharacter == "<" then
          Operator = Operator .. "="
          Tokenizer:Advance(State)
        end
      elseif Operator == "." then
        if State.TokenCharacter == "." then
          Operator = ".."
          Tokenizer:Advance(State)
        end
      elseif Operator == "/" then
        if State.TokenCharacter == "/" then
          Operator = "//"
          Tokenizer:Advance(State)
        end
      end

      if not IsComment then
        Tokenizer:AddToken(State, "Operator", Operator)
      end
    elseif StringHasLetter(BaseDigits, State.TokenCharacter) then
      local StartIndex = State.FileIndex

      if State.TokenCharacter == "0" then
        Tokenizer:Advance(State)

        if State.TokenCharacter == "x" or State.TokenCharacter == "X" then
          Tokenizer:Advance(State)

          while StringHasLetter("0123456789abcdefABCDEF", State.TokenCharacter) do
            Tokenizer:Advance(State)
          end

          local Digits = State.FileContent:sub(StartIndex + 2, State.FileIndex - 1)
          local Number = tonumber(Digits, 16)

          Tokenizer:AddToken(State, "Number", Number)
        elseif State.TokenCharacter == "b" or State.TokenCharacter == "B" then
          Tokenizer:Advance(State)

          while State.TokenCharacter == "0" or State.TokenCharacter == "1" do
            Tokenizer:Advance(State)
          end

          local Digits = State.FileContent:sub(StartIndex + 2, State.FileIndex - 1)
          local Number = tonumber(Digits, 2)

          Tokenizer:AddToken(State, "Number", Number)
        else
          while StringHasLetter(BaseDigits, State.TokenCharacter) do
            Tokenizer:Advance(State)
          end

          local Number = tonumber(State.FileContent:sub(StartIndex, State.FileIndex - 1))
          Tokenizer:AddToken(State, "Number", Number)
        end
      else
        while StringHasLetter(BaseDigits, State.TokenCharacter) do
          Tokenizer:Advance(State)
        end

        local Number = tonumber(State.FileContent:sub(StartIndex, State.FileIndex - 1))
        Tokenizer:AddToken(State, "Number", Number)
      end
    elseif State.TokenCharacter == '"' or State.TokenCharacter == "'" then
      local Quote = State.TokenCharacter
      Tokenizer:Advance(State)

      local StartIndex = State.FileIndex

      while State.TokenCharacter ~= Quote do
        local Character = Tokenizer:Advance(State)

        if Character == "\\" then
          Tokenizer:Advance(State)
        end
      end

      Tokenizer:Advance(State)

      Tokenizer:AddToken(State, "String", State.FileContent:sub(StartIndex, State.FileIndex - 2))
    elseif StringHasLetter(WhiteSpace, State.TokenCharacter) then
      Tokenizer:Advance(State)
    else
      if State.FileIndex > #State.FileContent then
      else
        Logger:Error(State, "Unexpected character: '%s'", State.TokenCharacter)
      end
      break
    end
  end
end

local Parser = {}

function Parser:Advance(State, Step)
  Step = Step or 1

  local PreviousToken = State.CurrentToken
  State.TokenIndex = State.TokenIndex + Step
  State.CurrentToken = State.Tokens[State.TokenIndex]
  if State.CurrentToken then
    State.Line = State.CurrentToken.Line
    State.Row = State.CurrentToken.Row
  end
end

function Parser:Initalize(State)
  State.Stop = false
  State.Ast = {}
  State.TokenIndex = 0
  Parser:Advance(State)
end

function Parser:Expect(State, ...)
  local Arguments = table.pack(...)

  if State.CurrentToken == nil then
    Logger:Error(State, "Unexpected end of file")
    State.Stop = true
    return nil, nil
  end

  local AllTokenKinds = {
    "Ident",
    "Punct",
    "Number",
    "Operator",
    "String",
    "Keyword",
  }

  if TableHasString(AllTokenKinds, Arguments[1]) then
    if TableHasString(Arguments, State.CurrentToken.Kind) then
      local Kind = State.CurrentToken.Kind
      local Value = State.CurrentToken.Value

      Parser:Advance(State)

      return Kind, Value
    end

    local HumanExpectedTokens = ""

    for Index, Value in ipairs(Arguments) do
      if Index > 1 then
        HumanExpectedTokens = HumanExpectedTokens .. " or "
      end

      HumanExpectedTokens = HumanExpectedTokens .. string.format("'%s'", Value)
    end

    Logger:Error(State, "Expected %s but got '%s'", HumanExpectedTokens, State.CurrentToken.Kind)

    State.Stop = true
    return nil, nil
  end

  for Index = 1, Arguments.n do
    if State.CurrentToken.Value == Arguments[Index] then
      local Kind = State.CurrentToken.Kind
      local Value = State.CurrentToken.Value

      Parser:Advance(State)

      return Kind, Value
    end
  end

  local HumanExpectedTokens = ""

  for Index = 1, Arguments.n do
    if Index > 1 then
      HumanExpectedTokens = HumanExpectedTokens .. " or "
    end

    HumanExpectedTokens = HumanExpectedTokens .. string.format("'%s'", Arguments[Index])
  end

  Logger:Error(State, "Expected %s but got '%s'", HumanExpectedTokens, State.CurrentToken.Value)

  State.Stop = true
  return nil, nil
end

function Parser:GetExpressionPrecedence(State)
  if State.CurrentToken == nil then
    return nil
  end

  return ExpressionPrecedence[State.CurrentToken.Value]
end

function Parser:ParsePrimaryExpression(State)
  if State.CurrentToken == nil then
    return nil
  end

  local Token = State.CurrentToken

  if Token.Kind == "Ident" then
    if Token.Value == "true" or Token.Value == "false" then
      Parser:Advance(State)

      return {
        Type = "Boolean",
        Value = Token.Value == "true",
      }
    end

    Parser:Advance(State)

    local Expression = {
      Type = "Ident",
      Value = Token.Value,
    }

    if State.CurrentToken and State.CurrentToken.Value == "(" then
      Parser:Advance(State)

      Expression = {
        Type = "FunctionCall",
        Name = Token.Value,
        Arguments = Parser:ParseArgumentList(State),
      }

      local Kind = Parser:Expect(State, ")")
      if Kind == nil then
        return nil
      end
    end

    return Expression
  end

  if Token.Kind == "Number" then
    Parser:Advance(State)

    return {
      Type = "Number",
      Value = Token.Value,
    }
  end

  if Token.Kind == "String" then
    Parser:Advance(State)

    return {
      Type = "String",
      Value = Token.Value,
    }
  end

  if Token.Value == "nil" then
    Parser:Advance(State)

    return {
      Type = "Nil",
      Value = nil,
    }
  end

  if Token.Value == "(" then
    Parser:Advance(State)

    local Expression = Parser:ParseExpression(State)

    local Kind = Parser:Expect(State, ")")
    if Kind == nil then
      return nil
    end

    return Expression
  end

  return nil
end

function Parser:ParseExpression(State, MinimumPrecedence)
  MinimumPrecedence = MinimumPrecedence or 0

  local Left = Parser:ParsePrimaryExpression(State)

  if Left == nil then
    return nil
  end

  while State.CurrentToken ~= nil do
    local Operator = State.CurrentToken.Value
    local Precedence = Parser:GetExpressionPrecedence(State)

    if Precedence == nil or Precedence < MinimumPrecedence then
      break
    end

    Parser:Advance(State)

    local Right = Parser:ParseExpression(State, Precedence + 1)

    if Right == nil then
      State.Stop = true
      return nil
    end

    Left = {
      Type = "BinaryExpression",
      Operator = Operator,
      Left = Left,
      Right = Right,
    }
  end

  return Left
end

function Parser:ParseArgumentList(State)
  local ArgumentList = {}

  local Argument
  while true do
    ArgumentNode = Parser:ParseExpression(State)
    table.insert(ArgumentList, ArgumentNode)

    if State.CurrentToken.Value ~= "," then
      break
    else
      Parser:Advance(State)
    end
  end

  return ArgumentList
end

function Parser:ParseBlock(State, ...)
  local Body = {}

  while true do
    if State.Stop then
      break
    elseif State.CurrentToken.Kind == "Keyword" and TableHasString({ ... }, State.CurrentToken.Value) then
      break
    end

    local Statement = Parser:ParseStatement(State)

    if Statement ~= nil then
      table.insert(Body, Statement)
    end
  end
  Parser:Expect(State, ...)

  return Body
end

function Parser:ParseFunctionCall(State, Statement)
  Statement.Type = "FunctionCall"
  Statement.Name = State.CurrentToken.Value
  Parser:Advance(State, 2)
  Statement.Arguments = Parser:ParseArgumentList(State)

  Kind, Value = Parser:Expect(State, ")")
  if Kind == nil then
    return
  end
end

function Parser:ParseVariableAssign(State, Statement)
  Statement.Type = "VariableAssign"
  Statement.Name = State.CurrentToken.Value
  Parser:Advance(State, 2)
  Statement.Value = Parser:ParseExpression(State)
end

function Parser:ParseFunction(State, Statement)
  Statement.Type = "Function"
  Statement.Name = State.CurrentToken.Value
  Parser:Advance(State)
  Statement.Arguments = Parser:ParseArgumentList(State)
  Statement.Body = Parser:ParseBlock(State, "end")
end

function Parser:ParseReturn(State, Statement)
  Statement.Type = "Return"
  Statement.Value = Parser:ParseExpression(State)
end

function Parser:ParseIf(State, Statement)
  Statement.Type = "If"
  Statement.Condition = Parser:ParseExpression(State)
  Parser:Advance(State)
  Statement.Body = Parser:ParseBlock(State, "end", "elseif", "else")
  Parser:Advance(State, -1)
  if State.CurrentToken.Value == "else" then
    Parser:Advance(State)
    Statement.Else = Parser:ParseBlock(State, "end")
  elseif State.CurrentToken.Value == "elseif" then
    Parser:Advance(State)
    Statement.ElseIf = {}
    Statement.Elseif = Parser:ParseIf(State, Statement.ElseIf, "end", "elseif", "else")
  elseif State.CurrentToken.Value == "end" then
    Parser:Advance(State)
  end
end

function Parser:ParseWhile(State, Statement)
  Statement.Type = "While"
  Statement.Condition = Parser:ParseExpression(State)
  Parser:Advance(State)
  Statement.Body = Parser:ParseBlock(State, "end")
end

function Parser:ParseStatement(State, IsLocal)
  local Statement = { Local = IsLocal or false }

  local Kind, Value = Parser:Expect(State, "Ident", "Keyword")
  if Kind == nil then
    return
  end

  if Kind == "Ident" then
    Kind, Value = Parser:Expect(State, "Punct", "Operator")
    if Kind == nil then
      return
    end

    if Value == "(" then
      Parser:Advance(State, -2)
      Parser:ParseFunctionCall(State, Statement)
    elseif Value == "=" then
      Parser:Advance(State, -2)
      Parser:ParseVariableAssign(State, Statement)
    else
      Logger:Error(State, "Expected '(' or '=' but got '%s'", State.CurrentToken.Value)
    end
  elseif Kind == "Keyword" then
    if Value == "local" then
      local Result = Parser:ParseStatement(State, true)
      return Result
    elseif Value == "function" then
      Parser:ParseFunction(State, Statement)
    elseif Value == "return" then
      Parser:ParseReturn(State, Statement)
    elseif Value == "if" then
      Parser:ParseIf(State, Statement)
    elseif Value == "while" then
      Parser:ParseWhile(State, Statement)
    else
      Logger:Error(State, "Unhandled keyword: %q", Value)
    end
  else
    Logger:Error(State, "Unhandled token kind: %q", Value)
  end

  return Statement
end

function Rua:Parse(State)
  Parser:Initalize(State)

  while State.CurrentToken ~= nil do
    if State.Stop then
      break
    end

    local Statement = Parser:ParseStatement(State)

    if Statement ~= nil then
      table.insert(State.Ast, Statement)
    end
  end
end

local LuaGenerator = {}

function LuaGenerator:Initalize(State)
  State.Lua.Program = ""
end

function LuaGenerator:IrToLua(Ir, Tab)
  if Ir.Type == "Label" then
    return string.format("function Label%d()\n", Ir.Arguments[1])
  elseif Ir.Type == "Jump" then
    return string.format("%sRuaRuntime:Jump(Label%s)\n", Tab, Ir.Arguments[1])
  else
    local Arguments = {}

    for _, Argument in ipairs(Ir.Arguments) do
      table.insert(Arguments, string.format("%q", Argument))
    end

    return string.format("%sRuaRuntime:%s(%s)\n", Tab, Ir.Type, table.concat(Arguments, ", "))
  end
end

function LuaGenerator:IrProgramToLua(State)
  local Lua = ""
  local Tab = "  "

  Lua = Lua .. "function Main()\n"

  for _, Ir in ipairs(State.Ir.Program) do
    if Ir.Type == "Label" then
      Lua = Lua .. "end\n\n"
      Lua = Lua .. string.format("function Label%d()\n", Ir.Arguments[1])
    elseif Ir.Type == "Comment" then
      Lua = Lua .. "--" .. Ir.Arguments[1] .. "\n"
    else
      Lua = Lua .. LuaGenerator:IrToLua(Ir, Tab)
    end
  end

  Lua = Lua .. "end\n"
  Lua = Lua .. "\nMain()"

  return Lua
end

function LuaGenerator:Generate(State)
  State.Lua.Program = LuaGenerator:IrProgramToLua(State)
end

local IrGenerator = {}

function IrGenerator:NewIr(State)
  table.insert(State.Ir.Program, State.CurrentIr)
  State.CurrentIr = {
    Arguments = {},
  }
end

function IrGenerator:NewBlankIr(State)
  State.CurrentIr = {
    Arguments = {},
  }
end

function IrGenerator:NewLabel(State)
  State.Ir.LabelCount = State.Ir.LabelCount + 1
  return State.Ir.LabelCount
end

function IrGenerator:GenerateBlock(State, Body)
  for _, Ast in ipairs(Body) do
    IrGenerator:GenerateIr(State, Ast)
  end
end

function IrGenerator:ConvertStringToIr(State, String)
  local ResultRegister = IrGenerator:GenerateIr(State, {
    Type = "String",
    Value = String,
  })

  return ResultRegister
end

function IrGenerator:AllocateRegister(State)
  for Register, Used in ipairs(State.Ir.Registers) do
    if not Used then
      IrGenerator:MarkUsed(State, Register)
      return Register
    end
  end

  Logger:Error(State, "Failed to allocate a register")
  return nil
end

function IrGenerator:MarkUsed(State, Register)
  State.Ir.Registers[Register] = true
end

function IrGenerator:MarkNotUsed(State, Register)
  for Index = #State.Ir.Scopes, 1, -1 do
    local Scope = State.Ir.Scopes[Index]

    for Name, ScopeRegister in pairs(Scope) do
      if Register == ScopeRegister then
        return
      end
    end
  end

  State.Ir.Registers[Register] = false
end

function IrGenerator:EnterScope(State)
  table.insert(State.Ir.Scopes, {})
end

function IrGenerator:LeaveScope(State)
  table.remove(State.Ir.Scopes)
end

function IrGenerator:DeclareLocal(State, Name, Register)
  local Scope = State.Ir.Scopes[#State.Ir.Scopes]
  Scope[Name] = Register
end

function IrGenerator:ResolveLocal(State, Name)
  for Index = #State.Ir.Scopes, 1, -1 do
    local Register = State.Ir.Scopes[Index][Name]

    if Register ~= nil then
      return Register
    end
  end

  return nil
end

function IrGenerator:GenerateIr(State, Ast)
  State.CurrentIr = { Arguments = {} }

  if Ast.Type == "FunctionCall" then
    for _, Argument in ipairs(Ast.Arguments) do
      local ArgumentRegister = IrGenerator:GenerateIr(State, Argument)

      State.CurrentIr.Type = "Push"
      State.CurrentIr.Arguments = {
        [1] = ArgumentRegister,
      }
      IrGenerator:MarkNotUsed(State, ArgumentRegister)
      IrGenerator:NewIr(State)
    end

    local FunctionNameRegister = IrGenerator:ConvertStringToIr(State, Ast.Name)
    local FunctionRegister = IrGenerator:AllocateRegister(State)

    State.CurrentIr.Type = "GetVariable"
    State.CurrentIr.Arguments = {
      [1] = FunctionNameRegister,
      [2] = FunctionRegister,
    }
    IrGenerator:MarkNotUsed(State, FunctionNameRegister)
    IrGenerator:NewIr(State)

    State.CurrentIr.Type = "CallFromRegister"
    State.CurrentIr.Arguments = {
      [1] = FunctionRegister,
    }
    IrGenerator:MarkNotUsed(State, FunctionRegister)
    IrGenerator:NewIr(State)

    local ResultRegister = IrGenerator:AllocateRegister(State)

    State.CurrentIr.Type = "Pop"
    State.CurrentIr.Arguments = {
      [1] = ResultRegister,
    }
    IrGenerator:NewIr(State)

    return ResultRegister
  elseif Ast.Type == "Function" then
    local EndLabel = IrGenerator:NewLabel(State)
    local FunctionLabel = IrGenerator:NewLabel(State)

    local FunctionNameRegister = IrGenerator:ConvertStringToIr(State, Ast.Name)

    State.CurrentIr.Type = "LoadFunction"
    State.CurrentIr.Arguments = {
      [1] = FunctionLabel,
      [2] = FunctionNameRegister,
      [3] = #Ast.Arguments,
    }
    IrGenerator:MarkNotUsed(State, FunctionNameRegister)
    IrGenerator:NewIr(State)

    State.CurrentIr.Type = "Jump"
    State.CurrentIr.Arguments = {
      [1] = EndLabel,
    }
    IrGenerator:NewIr(State)

    State.CurrentIr.Type = "Label"
    State.CurrentIr.Arguments = {
      [1] = FunctionLabel,
    }
    IrGenerator:NewIr(State)

    IrGenerator:EnterScope(State)

    for Index = #Ast.Arguments, 1, -1 do
      local Argument = Ast.Arguments[Index]
      local ArgumentRegister = IrGenerator:AllocateRegister(State)

      State.CurrentIr.Type = "Pop"
      State.CurrentIr.Arguments = {
        [1] = ArgumentRegister,
      }
      IrGenerator:NewIr(State)

      IrGenerator:DeclareLocal(State, Argument.Value, ArgumentRegister)
    end

    IrGenerator:GenerateBlock(State, Ast.Body)

    State.CurrentIr.Type = "Return"
    State.CurrentIr.Arguments = {}
    IrGenerator:NewIr(State)

    IrGenerator:LeaveScope(State)

    State.CurrentIr.Type = "Label"
    State.CurrentIr.Arguments = {
      [1] = EndLabel,
    }
    IrGenerator:NewIr(State)
  elseif Ast.Type == "Number" then
    local ResultRegister = IrGenerator:AllocateRegister(State)
    State.CurrentIr.Type = "LoadNumber"
    State.CurrentIr.Arguments = {
      [1] = Ast.Value,
      [2] = ResultRegister,
    }
    IrGenerator:NewIr(State)

    return ResultRegister
  elseif Ast.Type == "String" then
    local ResultRegister = IrGenerator:AllocateRegister(State)
    State.CurrentIr.Type = "LoadString"
    State.CurrentIr.Arguments = {
      [1] = Ast.Value,
      [2] = ResultRegister,
    }
    IrGenerator:NewIr(State)

    return ResultRegister
  elseif Ast.Type == "Ident" then
    local LocalRegister = IrGenerator:ResolveLocal(State, Ast.Value)

    if LocalRegister then
      return LocalRegister
    end

    local VariableNameRegister = IrGenerator:ConvertStringToIr(State, Ast.Value)
    local ResultRegister = IrGenerator:AllocateRegister(State)

    State.CurrentIr.Type = "GetVariable"
    State.CurrentIr.Arguments = {
      [1] = VariableNameRegister,
      [2] = ResultRegister,
    }

    IrGenerator:MarkNotUsed(State, VariableNameRegister)
    IrGenerator:NewIr(State)

    return ResultRegister
  elseif Ast.Type == "Boolean" then
    local ResultRegister = IrGenerator:AllocateRegister(State)
    State.CurrentIr.Type = "LoadBoolean"
    State.CurrentIr.Arguments = {
      [1] = Ast.Value,
      [2] = ResultRegister,
    }
    IrGenerator:NewIr(State)

    return ResultRegister
  elseif Ast.Type == "VariableAssign" then
    if Ast.Local then
      local LocalRegister = IrGenerator:GenerateIr(State, Ast.Value)
      IrGenerator:DeclareLocal(State, Ast.Name, LocalRegister)
      return LocalRegister
    end

    local LocalRegister = IrGenerator:ResolveLocal(State, Ast.Name)
    local ValueRegister = IrGenerator:GenerateIr(State, Ast.Value)

    if LocalRegister ~= nil then
      for Index = #State.Ir.Scopes, 1, -1 do
        local Scope = State.Ir.Scopes[Index]

        if Scope[Ast.Name] ~= nil then
          Scope[Ast.Name] = ValueRegister
          break
        end
      end

      State.CurrentIr.Type = "Copy"
      State.CurrentIr.Arguments = {
        [1] = LocalRegister,
        [2] = ValueRegister,
      }
      IrGenerator:NewIr(State)

      return ValueRegister
    end

    local VariableNameRegister = IrGenerator:ConvertStringToIr(State, Ast.Name)

    State.CurrentIr.Type = "VariableAssign"
    State.CurrentIr.Arguments = {
      [1] = VariableNameRegister,
      [2] = ValueRegister,
    }
    IrGenerator:MarkNotUsed(State, VariableNameRegister)
    IrGenerator:MarkNotUsed(State, ValueRegister)
    IrGenerator:NewIr(State)

    return ValueRegister
  elseif Ast.Type == "Return" then
    local ReturnRegister = IrGenerator:GenerateIr(State, Ast.Value)

    State.CurrentIr.Type = "Push"
    State.CurrentIr.Arguments = {
      [1] = ReturnRegister,
    }
    IrGenerator:MarkNotUsed(State, ReturnRegister)
    IrGenerator:NewIr(State)

    State.CurrentIr.Type = "Return"
    State.CurrentIr.Arguments = {}
    IrGenerator:NewIr(State)
  elseif Ast.Type == "If" then
    local ElseLabel = IrGenerator:NewLabel(State)
    local EndLabel = IrGenerator:NewLabel(State)

    local ResultRegister = IrGenerator:GenerateIr(State, Ast.Condition)

    State.CurrentIr.Type = "JumpIfFalseRegister"
    State.CurrentIr.Arguments = {
      [1] = ElseLabel,
      [2] = ResultRegister,
    }
    IrGenerator:MarkNotUsed(State, ResultRegister)
    IrGenerator:NewIr(State)

    IrGenerator:GenerateBlock(State, Ast.Body)

    State.CurrentIr.Type = "Jump"
    State.CurrentIr.Arguments = {
      [1] = EndLabel,
    }
    IrGenerator:NewIr(State)

    State.CurrentIr.Type = "Label"
    State.CurrentIr.Arguments = {
      [1] = ElseLabel,
    }
    IrGenerator:NewIr(State)

    if Ast.ElseIf then
      IrGenerator:GenerateIr(State, Ast.ElseIf)
    elseif Ast.Else then
      IrGenerator:GenerateBlock(State, Ast.Else)
    end

    State.CurrentIr.Type = "Label"
    State.CurrentIr.Arguments = {
      [1] = EndLabel,
    }
    IrGenerator:NewIr(State)
  elseif Ast.Type == "BinaryExpression" then
    local LeftRegister = IrGenerator:GenerateIr(State, Ast.Left)
    local RightRegister = IrGenerator:GenerateIr(State, Ast.Right)
    local ResultRegister
    if LeftRegister == RightRegister then
      ResultRegister = LeftRegister
    else
      ResultRegister = IrGenerator:AllocateRegister(State)
    end

    State.CurrentIr.Arguments = {
      [1] = LeftRegister,
      [2] = RightRegister,
      [3] = ResultRegister,
    }

    if Ast.Operator == "+" then
      State.CurrentIr.Type = "Add"
    elseif Ast.Operator == "-" then
      State.CurrentIr.Type = "Sub"
    elseif Ast.Operator == "/" then
      State.CurrentIr.Type = "Div"
    elseif Ast.Operator == "*" then
      State.CurrentIr.Type = "Mul"
    elseif Ast.Operator == "%" then
      State.CurrentIr.Type = "Mod"
    elseif Ast.Operator == "^" then
      State.CurrentIr.Type = "Pow"
    elseif Ast.Operator == "~=" then
      State.CurrentIr.Type = "NotEqual"
    elseif Ast.Operator == "==" then
      State.CurrentIr.Type = "Equal"
    elseif Ast.Operator == ">=" then
      State.CurrentIr.Type = "EqualOrGreaterThan"
    elseif Ast.Operator == "<=" then
      State.CurrentIr.Type = "EqualOrLessThan"
    elseif Ast.Operator == ">" then
      State.CurrentIr.Type = "GreaterThan"
    elseif Ast.Operator == "<" then
      State.CurrentIr.Type = "LessThan"
    elseif Ast.Operator == "&" then
      State.CurrentIr.Type = "NumberAnd"
    elseif Ast.Operator == "|" then
      State.CurrentIr.Type = "NumberOr"
    elseif Ast.Operator == "~" then
      State.CurrentIr.Type = "NumberXor"
    end
    IrGenerator:NewIr(State)

    IrGenerator:MarkNotUsed(State, LeftRegister)
    IrGenerator:MarkNotUsed(State, RightRegister)
    return ResultRegister
  elseif Ast.Type == "While" then
    local StartLabel = IrGenerator:NewLabel(State)
    local EndLabel = IrGenerator:NewLabel(State)

    State.CurrentIr.Type = "Label"
    State.CurrentIr.Arguments = {
      [1] = StartLabel,
    }
    IrGenerator:NewIr(State)

    local ResultRegister = IrGenerator:GenerateIr(State, Ast.Condition)

    State.CurrentIr.Type = "JumpIfFalseRegister"
    State.CurrentIr.Arguments = {
      [1] = EndLabel,
      [2] = ResultRegister,
    }
    IrGenerator:NewIr(State)

    IrGenerator:GenerateBlock(State, Ast.Body)

    State.CurrentIr.Type = "Jump"
    State.CurrentIr.Arguments = {
      [1] = StartLabel,
    }
    IrGenerator:NewIr(State)

    State.CurrentIr.Type = "Label"
    State.CurrentIr.Arguments = {
      [1] = EndLabel,
    }
    IrGenerator:NewIr(State)
  else
    Logger:Error(State, "Unhandled Ast type: %q", Ast.Type)
  end

  State.CurrentIr = { Arguments = {} }
end

function IrGenerator:Initalize(State)
  State.Ir.Registers = {}
  for _ = 1, 256 do
    table.insert(State.Ir.Registers, false)
  end

  State.Ir.Scopes = { {} }
end

function Rua:GenerateIr(State)
  IrGenerator:Initalize(State)

  for _, Ast in ipairs(State.Ast) do
    IrGenerator:GenerateIr(State, Ast)
  end
end

function Rua:GenerateLua(State)
  LuaGenerator:Initalize(State)
  LuaGenerator:Generate(State)
end

local BytecodeGenerator = {}

function BytecodeGenerator:Write8(State, Value)
  table.insert(State.Bytecode.ProgramTable, string.char(Value))
end

function BytecodeGenerator:Write16(State, Value)
  BytecodeGenerator:Write8(State, Value % 256)
  BytecodeGenerator:Write8(State, math.floor(Value / 256) % 256)
end

function BytecodeGenerator:Write32(State, Value)
  BytecodeGenerator:Write8(State, Value % 256)
  BytecodeGenerator:Write8(State, math.floor(Value / 256) % 256)
  BytecodeGenerator:Write8(State, math.floor(Value / 65536) % 256)
  BytecodeGenerator:Write8(State, math.floor(Value / 16777216) % 256)
end

function BytecodeGenerator:WriteBoolean(State, Value)
  BytecodeGenerator:Write8(State, Value and 1 or 0)
end

function BytecodeGenerator:WriteDouble(State, Value)
  table.insert(State.Bytecode.ProgramTable, string.pack("<d", Value))
end

function BytecodeGenerator:FindLabels(State)
  local Offset = 1

  for _, Ir in ipairs(State.Ir.Program) do
    if Ir.Type == "Label" then
      local Label = Ir.Arguments[1]

      State.Bytecode.Labels[Label] = Offset
    else
      Offset = Offset + BytecodeGenerator:GetInstructionSize(State, Ir)
    end
  end
end

function BytecodeGenerator:StripComments(State)
  local OriginalIrProgram = State.Ir.Program
  State.Ir.Program = {}

  for _, Ir in ipairs(OriginalIrProgram) do
    if Ir.Type ~= "Comment" then
      table.insert(State.Ir.Program, Ir)
    end
  end
end

function BytecodeGenerator:Initalize(State)
  State.Bytecode.Program = ""
  State.Bytecode.ProgramTable = {}
  State.Bytecode.Labels = {}
  BytecodeGenerator:StripComments(State)
  BytecodeGenerator:FindLabels(State)
end

function BytecodeGenerator:GetInstructionSize(State, Ir)
  local Size = 1
  local Schema = State.Bytecode.Isa.InstructionArguments[Ir.Type]

  for Index, ArgumentValue in pairs(Ir.Arguments) do
    local ArgumentType = Schema[Index].Type

    if TableHasString({ "Register", "RegisterString", "RegisterFunction" }, ArgumentType) then
      Size = Size + 1
    elseif ArgumentType == "Number" then
      Size = Size + 8
    elseif ArgumentType == "String" then
      Size = Size + 4 + #ArgumentValue
    elseif ArgumentType == "Boolean" then
      Size = Size + 1
    elseif ArgumentType == "Label" then
      Size = Size + 4
    else
      Logger:Error(State, "Unknown argument type: " .. tostring(Type))
      return
    end
  end

  return Size
end

function BytecodeGenerator:Generate(State, Ir)
  if Ir.Type == "Label" then
    return
  end

  local Instruction = State.Bytecode.Isa.Opcodes[Ir.Type]
  BytecodeGenerator:Write8(State, Instruction)

  local Schema = State.Bytecode.Isa.InstructionArguments[Ir.Type]

  for Index, ArgumentValue in ipairs(Ir.Arguments) do
    local ArgumentType = Schema[Index].Type

    if TableHasString({ "Register", "RegisterString", "RegisterFunction" }, ArgumentType) then
      BytecodeGenerator:Write8(State, ArgumentValue)
    elseif ArgumentType == "Number" then
      BytecodeGenerator:WriteDouble(State, ArgumentValue)
    elseif ArgumentType == "String" then
      BytecodeGenerator:Write32(State, #ArgumentValue)
      for Index = 1, #ArgumentValue do
        BytecodeGenerator:Write8(State, string.byte(ArgumentValue, Index))
      end
    elseif ArgumentType == "Boolean" then
      BytecodeGenerator:WriteBoolean(State, ArgumentValue)
    elseif ArgumentType == "Label" then
      local LabelAddress = State.Bytecode.Labels[ArgumentValue]
      BytecodeGenerator:Write32(State, LabelAddress)
    end
  end
end

function Rua:GenerateBytecode(State)
  BytecodeGenerator:Initalize(State)
  BytecodeGenerator:StripComments(State)

  for _, Ir in ipairs(State.Ir.Program) do
    BytecodeGenerator:Generate(State, Ir)
  end

  State.Bytecode.Program = table.concat(State.Bytecode.ProgramTable)
end

local Vm = {}

function Vm:Read8(State)
  local Value = string.byte(State.Bytecode.Program, State.Vm.Pc)
  State.Vm.Pc = State.Vm.Pc + 1

  return Value
end

function Vm:Read16(State)
  local Value = Vm:Read8(State)
  Value = Value + Vm:Read8(State) * 256

  return Value
end

function Vm:Read32(State)
  local Value = Vm:Read8(State)
  Value = Value + Vm:Read8(State) * 256
  Value = Value + Vm:Read8(State) * 65536
  Value = Value + Vm:Read8(State) * 16777216

  return Value
end

function Vm:ReadDouble(State)
  local Value
  Value, State.Vm.Pc = string.unpack("<d", State.Bytecode.Program, State.Vm.Pc)

  return Value
end

function Vm:ReadString(State)
  local Length = Vm:Read32(State)
  local Value = State.Bytecode.Program:sub(State.Vm.Pc, State.Vm.Pc + Length - 1)

  State.Vm.Pc = State.Vm.Pc + Length

  return Value
end

function Vm:GetRegister(State, Index)
  local Frame = State.Vm.Frames[#State.Vm.Frames]

  if Frame then
    return Frame.Registers[Index]
  end

  return State.Vm.Registers[Index]
end

function Vm:SetRegister(State, Index, NewRegister)
  local Frame = State.Vm.Frames[#State.Vm.Frames]

  if Frame then
    Frame.Registers[Index] = NewRegister
  else
    State.Vm.Registers[Index] = NewRegister
  end
end

function Vm:Decode(State)
  local Instruction = Vm:Read8(State)
  local Opcode

  for Name, Value in pairs(State.Bytecode.Isa.Opcodes) do
    if Value == Instruction then
      Opcode = Name
      break
    end
  end

  if not Opcode then
    Logger:Error(State, "Invalid opcode %d at bytecode position %d", Instruction, State.Vm.Pc - 1)
    return
  end

  local Schema = State.Bytecode.Isa.InstructionArguments[Opcode]
  local Arguments = {}

  for _, Argument in ipairs(Schema) do
    local Type = Argument.Type
    local Value

    if Type == "Register" or Type == "RegisterString" or Type == "RegisterFunction" then
      local RegisterIndex = Vm:Read8(State)
      Value = Vm:GetRegister(State, RegisterIndex)
      if State.Stop then
        return
      end

      if Type == "RegisterString" and Value.Type ~= "String" then
        Logger:Error(State, "Expected register's type as a string")
        return
      elseif Type == "RegisterFunction" and Value.Type ~= "Function" then
        Logger:Error(State, "Expected register's type as a function")
        return
      end
    elseif Type == "Number" then
      Value = Vm:ReadDouble(State)
    elseif Type == "String" then
      Value = Vm:ReadString(State)
    elseif Type == "Boolean" then
      Value = Vm:Read8(State) ~= 0
    elseif Type == "Label" then
      Value = Vm:Read32(State)
    else
      Logger:Error(State, "Unknown argument type: " .. tostring(Type))
      return
    end

    Arguments[Argument.Name] = Value
  end

  State.Vm.Opcode = Opcode
  State.Vm.Arguments = Arguments
end

function Vm:Execute(State)
  local Arguments = State.Vm.Arguments
  local Opcode = State.Vm.Opcode

  if Opcode == "CallFromRegister" then
    local FunctionRegister = Arguments.FunctionRegister
    local FunctionInfo = FunctionRegister.Value

    local LuaFunction = FunctionInfo.LuaFunction

    if LuaFunction ~= nil then
      local CallArguments = {}

      while #State.Vm.Stack > 0 do
        table.insert(CallArguments, 1, table.remove(State.Vm.Stack).Value)
      end

      LuaFunction(table.unpack(CallArguments))
    else
      table.insert(State.Vm.CallStack, State.Vm.Pc)
      State.Vm.Pc = FunctionInfo.Address

      local Frame = {
        Function = FunctionInfo,
        Pc = FunctionInfo.Address,
        Environment = {},
        Registers = {},
      }

      for Index = 1, 256 do
        Frame.Registers[Index] = {
          Type = "Nil",
          Value = nil,
        }
      end

      table.insert(State.Vm.Frames, Frame)
    end
  elseif Opcode == "LoadFunction" then
    local FunctionAddress = Arguments.FunctionAddress
    local FunctionName = Arguments.FunctionName.Value
    local FunctionArgumentCount = Arguments.FunctionArgumentCount

    State.Vm.Environment[FunctionName] = {
      Type = "Function",
      Value = {
        Name = FunctionName,
        Address = FunctionAddress,
        ArgumentCount = FunctionArgumentCount,
      },
    }
  elseif Opcode == "LoadNumber" then
    local ResultRegister = Arguments.ResultRegister
    ResultRegister.Type = "Number"
    ResultRegister.Value = Arguments.Number
  elseif Opcode == "LoadString" then
    local ResultRegister = Arguments.ResultRegister
    ResultRegister.Type = "String"
    ResultRegister.Value = Arguments.String
  elseif Opcode == "LoadBoolean" then
    local ResultRegister = Arguments.ResultRegister
    ResultRegister.Type = "Boolean"
    ResultRegister.Value = Arguments.Boolean
  elseif
    TableHasString({
      "Add",
      "Sub",
      "Mul",
      "Div",
      "Mod",
      "Pow",
      "NotEqual",
      "Equal",
      "EqualOrGreaterThan",
      "EqualOrLessThan",
      "GreaterThan",
      "LessThan",
      "NumberAnd",
      "NumberOr",
      "NumberXor",
    }, Opcode)
  then
    local Left = Arguments.LeftRegister.Value
    local Right = Arguments.RightRegister.Value
    local ResultRegister = Arguments.ResultRegister

    if Opcode == "Add" then
      ResultRegister.Value = Left + Right
    elseif Opcode == "Sub" then
      ResultRegister.Value = Left - Right
    elseif Opcode == "Mul" then
      ResultRegister.Value = Left * Right
    elseif Opcode == "Div" then
      ResultRegister.Value = Left / Right
    elseif Opcode == "Mod" then
      ResultRegister.Value = Left % Right
    elseif Opcode == "Pow" then
      ResultRegister.Value = Left ^ Right
    elseif Opcode == "NotEqual" then
      ResultRegister.Value = Left ~= Right
    elseif Opcode == "Equal" then
      ResultRegister.Value = Left == Right
    elseif Opcode == "EqualOrGreaterThan" then
      ResultRegister.Value = Left >= Right
    elseif Opcode == "EqualOrLessThan" then
      ResultRegister.Value = Left <= Right
    elseif Opcode == "GreaterThan" then
      ResultRegister.Value = Left > Right
    elseif Opcode == "LessThan" then
      ResultRegister.Value = Left < Right
    elseif Opcode == "NumberAnd" then
      ResultRegister.Value = Left & Right
    elseif Opcode == "NumberOr" then
      ResultRegister.Value = Left | Right
    elseif Opcode == "NumberXor" then
      ResultRegister.Value = Left ~ Right
    end

    if State.Bytecode.Isa.NumericOpcodes[Opcode] then
      ResultRegister.Type = "Number"
    elseif State.Bytecode.Isa.ComparisonOpcodes[Opcode] then
      ResultRegister.Type = "Boolean"
    end
  elseif Opcode == "JumpIfFalseTest" then
    if State.Vm.TestFailed then
      State.Vm.Pc = Arguments.ToAddress
    end
  elseif Opcode == "JumpIfTrueTest" then
    if not State.Vm.TestFailed then
      State.Vm.Pc = Arguments.ToAddress
    end
  elseif Opcode == "JumpIfFalseRegister" then
    local Value = Arguments.CheckRegister.Value

    if Value == nil or Value == false or Value == 0 then
      State.Vm.Pc = Arguments.ToAddress
    end
  elseif Opcode == "JumpIfTrueRegister" then
    local Value = Arguments.CheckRegister.Value

    if Value ~= nil and Value ~= false and Value ~= 0 then
      State.Vm.Pc = Arguments.ToAddress
    end
  elseif Opcode == "Jump" then
    State.Vm.Pc = Arguments.TargetAddress
  elseif Opcode == "Push" then
    local Register = Arguments.FromRegister

    table.insert(State.Vm.Stack, {
      Type = Register.Type,
      Value = Register.Value,
    })
  elseif Opcode == "Pop" then
    local Register = Arguments.ResultRegister
    local Top = table.remove(State.Vm.Stack)

    if Top == nil then
      Register.Type = "Nil"
      Register.Value = nil
    else
      Register.Type = Top.Type
      Register.Value = Top.Value
    end
  elseif Opcode == "Test" then
    local CheckRegister = Arguments.CheckRegister

    State.Vm.TestFailed = CheckRegister.Value == nil or CheckRegister.Value == false or CheckRegister.Value == 0
  elseif Opcode == "VariableAssign" then
    local VariableName = Arguments.VariableName.Value
    local VariableRegister = Arguments.VariableRegister

    State.Vm.Environment[VariableName] = {
      Type = VariableRegister.Type,
      Value = VariableRegister.Value,
    }
  elseif Opcode == "GetVariable" then
    local VariableName = Arguments.VariableName.Value
    local VariableRegister = Arguments.VariableRegister
    local Value

    local Frame = State.Vm.Frames[#State.Vm.Frames]
    if Frame then
      Value = Frame.Environment[VariableName]
      if not Value then
        Value = State.Vm.Environment[VariableName]
      end
    else
      Value = State.Vm.Environment[VariableName]
    end

    if Value then
      VariableRegister.Type = Value.Type
      VariableRegister.Value = Value.Value
    else
      VariableRegister.Type = "Nil"
      VariableRegister.Value = nil
    end
  elseif Opcode == "Return" then
    local ReturnPc = table.remove(State.Vm.CallStack)

    if ReturnPc then
      table.remove(State.Vm.Frames)
      State.Vm.Pc = ReturnPc
    else
      State.Vm.Pc = #State.Bytecode.Program + 1
    end
  elseif Opcode == "Copy" then
    local SourceRegister = Arguments.SourceRegister
    local DestinationRegister = Arguments.DestinationRegister

    SourceRegister.Type = DestinationRegister.Type
    SourceRegister.Value = DestinationRegister.Value
  else
    Logger:Error(State, "Unhandled opcode: %q", Opcode)
  end
end

function Vm:InitalizeRuntime(State)
  local Functions = {
    print = print,
  }

  for FunctionName, LuaFunction in pairs(Functions) do
    State.Vm.Environment[FunctionName] = {
      Type = "Function",
      Value = {
        Name = FunctionName,
        LuaFunction = LuaFunction,
      },
    }
  end
end

function Vm:Initalize(State)
  State.Vm.Pc = 1
  for Index = 1, 256 do
    State.Vm.Registers[Index] = {
      Type = "Nil",
      Value = nil,
    }
  end

  Vm:InitalizeRuntime(State)
end

function Vm:Run(State)
  local Result

  while State.Vm.Pc <= #State.Bytecode.Program do
    Vm:Decode(State)
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

function Rua:Execute(State)
  Vm:Initalize(State)
  return Vm:Run(State)
end

Rua.Logger = Logger
Rua.Tokenizer = Tokenizer
Rua.Parser = Parser
Rua.IrGenerator = IrGenerator
Rua.LuaGenerator = LuaGenerator
Rua.BytecodeGenerator = BytecodeGenerator
Rua.Vm = Vm

-- File -> Tokenizer -> Tokens -> Parser -> Ast ->
-- Ir generator -> Ir -> BytecodeGenerator -> Bytecode ->
-- Register-based Vm

return Rua
