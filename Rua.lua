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

--[[
  Rua.new()
    Creates and returns a new Rua compiler state

  Rua:Run(State, FileName)
    Reads the specified source file, tokenizes its contents,
    parses the tokens, and populates the resulting AST

  Rua:Tokenize(State)
    Tokenizes the source code stored in State.File.Content
    and stores the resulting tokens in State.Tokens

  Rua:Parse(State)
    Parses the tokens in State.Tokens and populates
    State.Ast
]]

--[[
  Parser:

  Standard Lua:
  Parse Function Call: Implemented
  Parse Variable Assignment: Implemented
  Parse Local Statement: Implemented
  Parse Function Declaration: Implemented
  Parse Expression: Implemented
  Parse Table Constructor: Implemented
  Parse Return: Implemented
  Parse Break: Implemented
  Parse If: Implemented
  Parse Else: Implemented
  Parse ElseIf: Implemented
  Parse While: Implemented
  Parse Repeat-Until: Implemented
  Parse Do Block: Implemented
  Parse Numeric For: Implemented
  Parse Generic For: Implemented
  Parse Multiple Assignment: Implemented
  Parse Local Variable Declaration: Implemented
  Parse Local Function Declaration: Implemented
  Parse Anonymous Function: Implemented
  Parse Method Call: Implemented
  Parse Member Access: Implemented
  Parse Table Indexing: Implemented
  Parse Goto: Implemented
  Parse Label: Implemented
  Parse Empty Statement (;): Implemented
  Parse Semicolon Separator: Implemented
  Parse Vararg Expression (...): Implemented
  Parse Function Parameters: Implemented
  Parse Multiple Return Values: Implemented
  Parse Unary Expression: Implemented
  Parse Binary Expression: Implemented
  Parse Parenthesized Expression: Implemented
  Parse Boolean Literal: Implemented
  Parse Nil Literal: Implemented
  Parse Number Literal: Implemented
  Parse String Literal: Implemented
  Parse Long String Literal: Implemented
  Parse Long Comment: Implemented
  Parse Concatenation Expression: Implemented
  Parse Logical Operators (and, or): Implemented
  Parse Comparison Operators: Implemented
  Parse Arithmetic Operators: Implemented
  Parse Bitwise Operators: Implemented
  Parse Floor Division Operator (//): Implemented
  Parse Exponentiation Operator (^): Implemented
  Parse Function Call Expressions: Implemented
  Parse Table Field Separators (, and ;): Implemented
  Parse Syntax Error Recovery: Implemented
 
  Non-Lua extensions:
  Parse Continue: Implemented
  Parse C-like Macro: Not Implemented
  Parse Switch Statement: Not Implemented
  Parse Match Expression: Not Implemented
  Parse Unless Statement: Not Implemented
  Parse Infinite Loop: Not Implemented
  Parse Defer Statement: Not Implemented
  Parse Fallthrough Statement: Not Implemented
  Parse Const Declaration: Not Implemented
  Parse Compound Assignment: Not Implemented
  Parse Increment Operator (++): Not Implemented
  Parse Decrement Operator (--): Not Implemented
  Parse Swap Assignment: Not Implemented
  Parse Array Destructuring: Not Implemented
  Parse Table Destructuring: Not Implemented
  Parse Ternary Expression: Not Implemented
  Parse Null-Coalescing Operator (??): Not Implemented
  Parse Optional Chaining (?.): Not Implemented
  Parse Pipeline Operator (|>): Not Implemented
  Parse Elvis Operator (?:): Not Implemented
  Parse Membership Operator (in): Not Implemented
  Parse Non-Nil Assertion (!): Not Implemented
  Parse String Interpolation: Not Implemented
  Parse Spread Operator: Not Implemented
  Parse Arrow Function: Not Implemented
  Parse Default Parameters: Not Implemented
  Parse Named Arguments: Not Implemented
  Parse Try Statement: Not Implemented
  Parse Catch Clause: Not Implemented
  Parse Finally Clause: Not Implemented
  Parse Throw Statement: Not Implemented
  Parse Assert Expression: Not Implemented
  Parse Class Declaration: Not Implemented
  Parse Constructor: Not Implemented
  Parse Inheritance: Not Implemented
  Parse Interface Declaration: Not Implemented
  Parse Trait Declaration: Not Implemented
  Parse Static Method: Not Implemented
  Parse Property Declaration: Not Implemented
  Parse Operator Overloading: Not Implemented
  Parse Import Statement: Not Implemented
  Parse Export Statement: Not Implemented
  Parse Import Alias: Not Implemented
  Parse Import All: Not Implemented
  Parse Namespace Declaration: Not Implemented
  Parse Module Declaration: Not Implemented
  Parse Type Annotation: Not Implemented
  Parse Type Alias: Not Implemented
  Parse Union Type: Not Implemented
  Parse Intersection Type: Not Implemented
  Parse Generic Function: Not Implemented
  Parse Generic Type: Not Implemented
  Parse Enum Declaration: Not Implemented
  Parse Struct Declaration: Not Implemented
  Parse Optional Type: Not Implemented
  Parse Function Type: Not Implemented
  Parse Type Cast: Not Implemented
  Parse Runtime Type Check: Not Implemented
  Parse Range Expression: Not Implemented
  Parse Do Expression: Not Implemented
  Parse Block Expression: Not Implemented
  Parse Compile-Time Constant: Not Implemented
  Parse Macro Invocation: Not Implemented
  Parse Raw String Literal: Not Implemented
  Parse Numeric Separators: Not Implemented
  Parse Binary Integer Literal: Not Implemented
  Parse Multiline String: Not Implemented
  Parse Named Table Field Shorthand: Not Implemented
  Parse Computed Table Fields: Not Implemented

  IrGenerator:
  Generate Function Call: Implemented
  Generate Variable Assignment: Implemented
  Generate Local Statement: Partially Implemented
  Generate Function Declaration: Partially Implemented
  Generate Return: Partially Implemented
  Generate Break: Not Implemented
  Generate Method Call: Not Implemented
  Generate If: Not Implemented
  Generate While: Implemented
  Generate Do Block: Not Implemented
  Generate Expression: Implemented
  Generate Binary Expression: Implemented
  Generate Unary Expression: Implemented
  Generate Identifier: Partially Implemented
  Generate Number Literal: Implemented
  Generate String Literal: Implemented
  Generate Boolean Literal: Implemented
  Generate Nil Literal: Implemented
  Generate Table Constructor: Not Implemented
  Generate Table Indexing: Not Implemented
  Generate Member Access: Not Implemented
  Generate Anonymous Function: Not Implemented
  Generate Conditional Jump: Not Implemented
  Generate Unconditional Jump: Not Implemented
  Generate Labels: Not Implemented
]]

local Rua = {}

local Ansi = {
  Reset = "\27[0m",
  Yellow = "\27[33m",
  Red = "\27[31m",
  RuaRed = "\27[38;2;255;100;100m",
  LuaBlue = "\27[38;2;100;200;255m",
}

local Logger = {}
local Tokenizer = {}
local Parser = {}
local AstDesugar = {}
local IrGenerator = {}

local BaseIdent = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
local BasePunct = "(){}[];,:."
local BaseDigits = "0123456789"
local BaseOperators = "=<>~&|+-*/^%#"

local BaseKeywords = {
  "and",
  "break",
  "continue",
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

local BaseEscapes = {
  ["n"] = "\n",
  ["t"] = "\t",
  ["r"] = "\r",
  ["\\"] = "\\",
  ['"'] = '"',
  ["'"] = "'",
  ["0"] = "\0",
}

local BinaryPrecedence = {
  ["or"] = 1,
  ["and"] = 2,

  ["<"] = 3,
  [">"] = 3,
  ["<="] = 3,
  [">="] = 3,
  ["=="] = 3,
  ["~="] = 3,

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

  ["^"] = 12,
}

local RightAssociative = {
  [".."] = true,
  ["^"] = true,
}

local WhiteSpace = "\n\t\r "

local function TableHasString(Table, Value)
  for _, Item in pairs(Table) do
    if type(Item) == "string" and Item == Value then
      return true
    end
  end

  return false
end

local function StringHasLetter(String, Letter)
  return Letter ~= "" and string.find(String, Letter, 1, true) ~= nil
end

local function PrintTable(Value, Indent)
  Indent = Indent or 0

  for Key, Item in pairs(Value) do
    io.write(string.rep("  ", Indent))
    if type(Key) == "string" then
      io.write(string.format("[%q] = ", Key))
    else
      io.write(string.format("[%s] = ", Key))
    end

    if type(Item) == "table" then
      io.write("{\n")
      PrintTable(Item, Indent + 1)
      io.write(string.rep("  ", Indent) .. "}\n")
    else
      if type(Item) == "string" then
        io.write(string.format("%q\n", Item))
      else
        io.write(string.format("%s\n", Item))
      end
    end
  end
end

local function GenerateRandomName()
  local Characters = BaseIdent .. BaseDigits
  local Result = {}

  for Idx = 1, 64 do
    local RandomIndex = math.random(#Characters)
    Result[Idx] = Characters:sub(RandomIndex, RandomIndex)
  end

  return "__Rua_BuildTime_TemporaryRandom__" .. table.concat(Result)
end

function Logger:Error(State, ErrorType, ErrorMessageFormat, ...)
  local Format = "%sRua:%s %s:%d:%d: %sError:%s %s: %s\n"

  State.ErrorMessage = string.format(ErrorMessageFormat, ...)

  io.write(
    string.format(
      Format,
      Ansi.RuaRed,
      Ansi.Reset,
      State.File.Name,
      State.File.Row,
      State.File.Column,
      Ansi.Red,
      Ansi.Reset,
      ErrorType,
      State.ErrorMessage
    )
  )

  State.Stop = true

  if Rua.DevMode then
    io.write(
      string.format(
        "%sLua:%s traceback:\n%s\n",
        Ansi.LuaBlue,
        Ansi.Reset,
        debug.traceback():gsub("stack traceback:\n", ""):gsub("	", "   ")
      )
    )
  end

  if ErrorType == "SyntaxError" then
    Parser:Advance(State)
  else
    if os.exit then
      os.exit(1)
    else
      assert(false, "")
    end
  end

  return State.ErrorMessage
end

function Tokenizer:Reset(State)
  Tokenizer.Index = 0
  Tokenizer.Character = ""
  State.File.Row = 1
  State.File.Column = 0
end

function Tokenizer:Advance(State, Step)
  Step = Step or 1

  local Direction = Step < 0 and -1 or 1
  for _ = 1, math.abs(Step) do
    local Index = Tokenizer.Index + Direction
    local Character = State.File.Content:sub(Index, Index)

    Tokenizer.Index = Index
    Tokenizer.Character = Character

    if Character == "\n" then
      State.File.Row = State.File.Row + 1
      State.File.Column = 0
    else
      State.File.Column = State.File.Column + 1
    end
  end
end

function Tokenizer:NewToken(State)
  Tokenizer.Token.Row = State.File.Row
  Tokenizer.Token.Column = State.File.Column

  table.insert(State.Tokens, Tokenizer.Token)
  Tokenizer.Token = {}
end

function Tokenizer:TokenizeIdent(State)
  local StartIndex = Tokenizer.Index

  while StringHasLetter(BaseIdent, Tokenizer.Character) or StringHasLetter(BaseDigits, Tokenizer.Character) do
    Tokenizer:Advance(State)
  end

  local EndIndex = Tokenizer.Index - 1
  local Ident = State.File.Content:sub(StartIndex, EndIndex)
  local Kind = TableHasString(BaseKeywords, Ident) and "Keyword" or "Ident"

  Tokenizer.Token = {
    Kind = Kind,
    Value = Ident,
  }

  Tokenizer:NewToken(State)
end

function Tokenizer:TokenizePunct(State)
  if Tokenizer.Character == "." then
    local Start = Tokenizer.Index

    Tokenizer:Advance(State)
    if Tokenizer.Character == "." then
      Tokenizer:Advance(State)
      if Tokenizer.Character == "." then
        Tokenizer.Token = {
          Kind = "Ident",
          Value = "...",
        }

        Tokenizer:NewToken(State)
        Tokenizer:Advance(State)
        return
      else
        Tokenizer:Advance(State, Start - Tokenizer.Index)
      end
    else
      Tokenizer:Advance(State, Start - Tokenizer.Index)
    end
  elseif Tokenizer.Character == ":" then
    local Start = Tokenizer.Index

    Tokenizer:Advance(State)
    if Tokenizer.Character == ":" then
      Tokenizer.Token = {
        Kind = "Punct",
        Value = "::",
      }

      Tokenizer:NewToken(State)
      Tokenizer:Advance(State)
      return
    else
      Tokenizer:Advance(State, Start - Tokenizer.Index)
    end
  elseif Tokenizer.Character == "[" then
    Tokenizer:Advance(State)

    if StringHasLetter("[=", Tokenizer.Character) then
      Tokenizer:Advance(State, -1)
      Tokenizer:TokenizeString(State)
      return
    end
  end

  Tokenizer.Token = {
    Kind = "Punct",
    Value = Tokenizer.Character,
  }

  Tokenizer:NewToken(State)
  Tokenizer:Advance(State)
end

function Tokenizer:TokenizeNumber(State)
  local StartIndex = Tokenizer.Index
  local FirstDigit = true
  local Base = 10

  while StringHasLetter(BaseDigits, Tokenizer.Character) or Tokenizer.Character == "." do
    Tokenizer:Advance(State)

    if FirstDigit and TableHasString({ "x", "b" }, Tokenizer.Character) then
      Base = Tokenizer.Character == "x" and 16 or 2
      StartIndex = StartIndex + 2
      Tokenizer:Advance(State)
    end

    FirstDigit = false
  end

  local EndIndex = Tokenizer.Index - 1
  local Number = State.File.Content:sub(StartIndex, EndIndex)

  if Number == nil then
    Logger:Error(State, "SyntaxError", "Invalid number literal: %s", Number)
  end

  Tokenizer.Token = {
    Kind = "Number",
    Value = tonumber(Number, Base),
  }

  Tokenizer:NewToken(State)
end

function Tokenizer:TokenizeString(State)
  local StringCharacter = Tokenizer.Character
  local String, IsMultipleLineString, StringLevel = "", false, 0

  if Tokenizer.Character == "[" then
    Tokenizer:Advance(State)

    while Tokenizer.Character == "=" do
      StringLevel = StringLevel + 1
      Tokenizer:Advance(State)
    end

    if Tokenizer.Character == "[" then
      Tokenizer:Advance(State)
      IsMultipleLineString = true
    end
  end

  Tokenizer:Advance(State)

  while Tokenizer.Character ~= StringCharacter do
    if Tokenizer.Character == "" then
      Logger:Error(State, "SyntaxError", "Unterminated string")
      return
    elseif Tokenizer.Character == "\\" then
      Tokenizer:Advance(State)

      if Tokenizer.Character == "" then
        Logger:Error(State, "SyntaxError", "Unterminated escape sequence")
        return
      end

      local Escape = BaseEscapes[Tokenizer.Character]

      if Escape ~= nil then
        String = String .. Escape
      elseif StringHasLetter(BaseDigits, Tokenizer.Character) then
        local StartIndex = Tokenizer.Index

        while StringHasLetter(BaseDigits, Tokenizer.Character) do
          Tokenizer:Advance(State)
        end
        local EndIndex = Tokenizer.Index - 1

        local NumberString = State.File.Content:sub(StartIndex, EndIndex)
        local Number = tonumber(NumberString)
        local Character = string.char(Number)
        String = String .. Character
      else
        Logger:Error(State, "SyntaxError", "Invalid escape sequence: \\%s", Tokenizer.Character)
        return
      end
    elseif IsMultipleLineString and Tokenizer.Character == "]" then
      Tokenizer:Advance(State)

      for Idx = 0, StringLevel do
        if Tokenizer.Character ~= "]" then
          goto continue
        end
      end

      if Tokenizer.Character == "]" then
        Tokenizer:Advance(State)
        break
      end
    else
      String = String .. Tokenizer.Character
    end

    if #Tokenizer.Character == 0 then
      Logger:Error(State, "SyntaxError", "Unterminated string")
    end

    Tokenizer:Advance(State)

    ::continue::
  end

  Tokenizer.Token = {
    Kind = "String",
    Value = String,
  }

  Tokenizer:NewToken(State)
  Tokenizer:Advance(State)
end

function Tokenizer:TokenizeOperator(State)
  local IsComment, IsMultipleLineComment, CommentLevel = false, false, 0
  local Operator = Tokenizer.Character

  Tokenizer:Advance(State)

  if Operator == "-" and Tokenizer.Character == "-" then
    IsComment = true
    Tokenizer:Advance(State)

    if Tokenizer.Character == "[" then
      Tokenizer:Advance(State)

      while Tokenizer.Character == "=" do
        CommentLevel = CommentLevel + 1
        Tokenizer:Advance(State)
      end

      if Tokenizer.Character == "[" then
        Tokenizer:Advance(State)
        IsMultipleLineComment = true
      end
    end
  elseif TableHasString({ "=", "~", ">", "<", "|" }, Operator) then
    if Tokenizer.Character == "=" then
      Operator = Operator .. "="
      Tokenizer:Advance(State)
    elseif TableHasString({ ">", "<" }, Tokenizer.Character) then
      Operator = Operator .. Tokenizer.Character
      Tokenizer:Advance(State)
    end
  end

  if IsComment then
    while #Tokenizer.Character > 0 do
      if not IsMultipleLineComment then
        if Tokenizer.Character == "\n" then
          break
        end
      elseif IsMultipleLineComment and Tokenizer.Character == "]" then
        Tokenizer:Advance(State)

        for Idx = 0, CommentLevel do
          if Tokenizer.Character ~= "=" then
            goto continue
          end
        end

        if Tokenizer.Character == "]" then
          Tokenizer:Advance(State)
          break
        end

        goto continue
      end

      Tokenizer:Advance(State)

      ::continue::
    end
  else
    Tokenizer.Token = {
      Kind = "Operator",
      Value = Operator,
    }

    Tokenizer:NewToken(State)
  end
end

function Tokenizer:Tokenize(State)
  Tokenizer:Advance(State)

  while #Tokenizer.Character > 0 do
    if StringHasLetter(BaseIdent, Tokenizer.Character) then
      Tokenizer:TokenizeIdent(State)
    elseif StringHasLetter(BasePunct, Tokenizer.Character) then
      Tokenizer:TokenizePunct(State)
    elseif StringHasLetter(BaseDigits, Tokenizer.Character) then
      Tokenizer:TokenizeNumber(State)
    elseif Tokenizer.Character == '"' or Tokenizer.Character == "'" then
      Tokenizer:TokenizeString(State)
    elseif StringHasLetter(BaseOperators, Tokenizer.Character) then
      Tokenizer:TokenizeOperator(State)
    elseif StringHasLetter(WhiteSpace, Tokenizer.Character) then
      Tokenizer:Advance(State)
    else
      Logger:Error(State, "SyntaxError", "Unexpected character: %s", Tokenizer.Character)
      return
    end
  end
end

function Parser:Expect(State, Kind, Value)
  local ValidType = false

  if type(Kind) == "table" then
    ValidType = TableHasString(Kind, Parser.Token.Kind)
  else
    ValidType = Parser.Token.Kind == Kind
  end

  if not ValidType or (Value ~= nil and Parser.Token.Value ~= Value) then
    Logger:Error(State, "SyntaxError", "Unexpected token '%s'", Parser.Token.Value)
    return nil
  end

  Parser:Advance(State)
  return Parser.Token
end

function Parser:CheckToken(State, ExpectedToken)
  if not ExpectedToken.Value then
    if Parser.Token.Kind == ExpectedToken.Kind then
      return Parser.Token
    end
  else
    if Parser.Token.Kind == ExpectedToken.Kind and Parser.Token.Value == ExpectedToken.Value then
      return Parser.Token
    end
  end

  return nil
end

function Parser:Advance(State, Step)
  Step = Step or 1

  local NextIndex = Parser.Index + Step
  local Token = State.Tokens[NextIndex]
  Parser.Token = Token
  Parser.Index = NextIndex
end

function Parser:GoToStart(State)
  local Token = State.Tokens[Parser.StartIndex]
  Parser.Index = Parser.StartIndex
  Parser.Token = Token
end

function Parser:Peek(State, Offset)
  return State.Tokens[Parser.Index + (Offset or 1)]
end

function Parser:Match(State, Value)
  if Parser.Token and Parser.Token.Value == Value then
    Parser:Advance(State)
    return true
  end

  return false
end

function Parser:ExpectValue(State, Value)
  if not Parser.Token or Parser.Token.Value ~= Value then
    Logger:Error(
      State,
      "SyntaxError",
      "Expected '%s', got '%s'",
      Value,
      Parser.Token and tostring(Parser.Token.Value) or "end of file"
    )

    return false
  end

  Parser:Advance(State)
  return true
end

function Parser:ParseTableConstructor(State)
  if not Parser:ExpectValue(State, "{") then
    return nil
  end

  local Node = {
    Kind = "Table",
    Fields = {},
  }

  while Parser.Token and Parser.Token.Value ~= "}" do
    local Field

    if Parser:Match(State, "[") then
      local Key = Parser:ParseExpression(State)

      if not Key or not Parser:ExpectValue(State, "]") then
        return nil
      end

      if not Parser:ExpectValue(State, "=") then
        return nil
      end

      local Value = Parser:ParseExpression(State)

      Field = {
        Kind = "KeyValue",
        Key = Key,
        Value = Value,
      }
    elseif Parser.Token.Kind == "Ident" and self:Peek(State) and self:Peek(State).Value == "=" then
      local Key = {
        Kind = "String",
        Value = Parser.Token.Value,
      }

      Parser:Advance(State)
      Parser:Advance(State)

      local Value = Parser:ParseExpression(State)

      Field = {
        Kind = "KeyValue",
        Key = Key,
        Value = Value,
      }
    else
      local Value = Parser:ParseExpression(State)

      Field = {
        Kind = "ArrayValue",
        Value = Value,
      }
    end

    if not Field or not Field.Value then
      return nil
    end

    table.insert(Node.Fields, Field)

    if Parser:Match(State, "}") then
      return Node
    end

    if not Parser:Match(State, ",") and not Parser:Match(State, ";") then
      Logger:Error(State, "SyntaxError", "Expected ',' or '}' in table constructor")
      return nil
    end
  end

  if not Parser:ExpectValue(State, "}") then
    return nil
  end

  return Node
end

function Parser:ParsePrimaryExpression(State)
  local Token = Parser.Token

  if not Token then
    Logger:Error(State, "SyntaxError", "Expected an expression")
    return nil
  end

  local Node = {}

  if Token.Kind == "Number" then
    Node = {
      Kind = "Number",
      Value = Token.Value,
    }

    Parser:Advance(State)
  elseif Token.Kind == "String" then
    Node = {
      Kind = "String",
      Value = Token.Value,
    }

    Parser:Advance(State)
  elseif
    Token.Kind == "Ident"
    or (Token.Kind == "Keyword" and (Token.Value == "true" or Token.Value == "false" or Token.Value == "nil"))
  then
    if Token.Value == "true" or Token.Value == "false" then
      Node = {
        Kind = "Boolean",
        Value = Token.Value == "true",
      }
    elseif Token.Value == "nil" then
      Node = {
        Kind = "Nil",
      }
    else
      Node = {
        Kind = "Identifier",
        Name = Token.Value,
      }
    end

    Parser:Advance(State)
  elseif Token.Value == "(" then
    Parser:Advance(State)

    Node = Parser:ParseExpression(State)

    if not Node or not Parser:ExpectValue(State, ")") then
      return nil
    end

    Node = {
      Kind = "Group",
      Expression = Node,
    }
  elseif Token.Value == "{" then
    Node = Parser:ParseTableConstructor(State)

    if not Node then
      return nil
    end
  elseif Token.Value == "not" or Token.Value == "-" or Token.Value == "#" or Token.Value == "~" then
    local Operator = Token.Value
    Parser:Advance(State)

    local Operand = Parser:ParseExpression(State, 11)

    if not Operand then
      return nil
    end

    Node = {
      Kind = "Unary",
      Operator = Operator,
      Operand = Operand,
    }
  elseif Token.Kind == "Keyword" and Token.Value == "function" then
    Node.Kind = "Function"
    Parser:Advance(State)
    Parser:ParseArgumentList(State, Node)

    local Body = Parser:ParseBody(State, { "end" })
    Node.Body = Body

    Parser:Expect(State, "Keyword", "end")
  else
    Logger:Error(State, "SyntaxError", "Expected an expression, got '%s'", tostring(Token.Value))

    return nil
  end

  while Parser.Token do
    if Parser:Match(State, ".") then
      local Member = Parser.Token

      if not Member or Member.Kind ~= "Ident" then
        Logger:Error(State, "SyntaxError", "Expected member name after '.'")
        return nil
      end

      Parser:Advance(State)

      Node = {
        Kind = "Member",
        Table = Node,
        Name = Member.Value,
      }
    elseif Parser:Match(State, "[") then
      local Index = Parser:ParseExpression(State)

      if not Index or not Parser:ExpectValue(State, "]") then
        return nil
      end

      Node = {
        Kind = "Index",
        Table = Node,
        Index = Index,
      }
    elseif Parser:Match(State, ":") then
      local Method = Parser.Token

      if not Method or Method.Kind ~= "Ident" then
        Logger:Error(State, "SyntaxError", "Expected method name after ':'")
        return nil
      end

      Parser:Advance(State)

      if not Parser:ExpectValue(State, "(") then
        return nil
      end

      local Arguments = {}

      if not Parser:Match(State, ")") then
        repeat
          local Argument = Parser:ParseExpression(State)

          if not Argument then
            return nil
          end

          table.insert(Arguments, Argument)
        until not Parser:Match(State, ",")

        if not Parser:ExpectValue(State, ")") then
          return nil
        end
      end

      Node = {
        Kind = "MethodCall",
        Table = Node,
        Name = Method.Value,
        Arguments = Arguments,
      }
    elseif Parser:Match(State, "(") then
      local Arguments = {}

      if not Parser:Match(State, ")") then
        repeat
          local Argument = Parser:ParseExpression(State)

          if not Argument then
            return nil
          end

          table.insert(Arguments, Argument)
        until not Parser:Match(State, ",")

        if not Parser:ExpectValue(State, ")") then
          return nil
        end
      end

      Node = {
        Kind = "FunctionCall",
        Name = Node,
        Arguments = Arguments,
      }
    else
      break
    end
  end

  return Node
end

function Parser:ParseExpression(State, MinPrecedence)
  MinPrecedence = MinPrecedence or 1

  local Left = Parser:ParsePrimaryExpression(State)

  if not Left then
    return nil
  end

  while Parser.Token do
    local Operator = Parser.Token.Value
    local Precedence = BinaryPrecedence[Operator]

    if not Precedence or Precedence < MinPrecedence then
      break
    end

    Parser:Advance(State)

    local NextPrecedence = Precedence + 1

    if RightAssociative[Operator] then
      NextPrecedence = Precedence
    end

    local Right = Parser:ParseExpression(State, NextPrecedence)

    if not Right then
      return nil
    end

    Left = {
      Kind = "Binary",
      Operator = Operator,
      Left = Left,
      Right = Right,
    }
  end

  return Left
end

function Parser:ParseExpressionList(State)
  local Expressions = {}

  local Expression = Parser:ParseExpression(State)

  if not Expression then
    return nil
  end

  table.insert(Expressions, Expression)

  while Parser:Match(State, ",") do
    local Expression = Parser:ParseExpression(State)

    if not Expression then
      return nil
    end

    table.insert(Expressions, Expression)
  end

  return Expressions
end

function Parser:ParseName(State)
  local Token = Parser.Token

  if not Token or Token.Kind ~= "Ident" then
    Logger:Error(State, "SyntaxError", "Expected a name")
    return nil
  end

  local Node = {
    Kind = "Identifier",
    Name = Token.Value,
  }

  Parser:Advance(State)

  while Parser.Token and (Parser.Token.Value == "." or Parser.Token.Value == ":") do
    local Separator = Parser.Token.Value
    Parser:Advance(State)

    local Member = Parser.Token

    if not Member or Member.Kind ~= "Ident" then
      Logger:Error(State, "SyntaxError", "Expected name after '%s'", Separator)
      return nil
    end

    Node = {
      Kind = "Member",
      Table = Node,
      Name = Member.Value,
      Separator = Separator,
    }

    Parser:Advance(State)
  end

  return Node
end

function Parser:ParseNameList(State)
  return Parser:ParseExpressionList(State)
end

function Parser:ParseArgumentList(State, Statement)
  Statement.Arguments = {}
  while true do
    Parser:Advance(State)

    if Parser.Token == nil then
      break
    end

    if Parser:CheckToken(State, {
      Kind = "Punct",
      Value = ")",
    }) then
      break
    end

    if Parser:CheckToken(State, {
      Kind = "Punct",
      Value = ",",
    }) then
      Parser:Advance(State)
    end

    local Argument = Parser:ParseExpression(State)
    Parser:Advance(State, -1)
    table.insert(Statement.Arguments, Argument)
  end
  Parser:Advance(State)
end

function Parser:ParseBody(State, AllowedEnds)
  local Body = {}
  local HasEnd = false

  while Parser.Token ~= nil do
    local IsEnd = false

    for _, AllowedEnd in pairs(AllowedEnds) do
      if Parser:CheckToken(State, {
        Kind = "Keyword",
        Value = AllowedEnd,
      }) then
        IsEnd = true
        HasEnd = true
        break
      end
    end

    if IsEnd then
      break
    end

    local Statement = Parser:ParseStatement(State)
    table.insert(Body, Statement)
  end

  if not HasEnd then
    Logger:Error(State, "SyntaxError", "Expected '" .. table.concat(AllowedEnds, "' or '") .. "' before end of file")
  end

  return Body
end

function Parser:ParseFunctionCall(State, Statement)
  Statement.Kind = "FunctionCall"
  Statement.Name = Parser:ParseName(State)

  Parser:ParseArgumentList(State, Statement)
end

function Parser:ParseFunction(State, Statement)
  Statement.Kind = "Function"
  Parser:Expect(State, "Keyword", "function")
  Statement.Name = Parser:ParseName(State)

  Parser:ParseArgumentList(State, Statement)

  local Body = Parser:ParseBody(State, { "end" })
  Statement.Body = Body
  Parser:Advance(State)
end

function Parser:ParseVariableAssign(State, Statement)
  Statement.Kind = "VariableAssign"
  Statement.Name = Parser:ParseNameList(State)
  Parser:Advance(State)
  local Value = Parser:ParseExpressionList(State)
  Statement.Value = Value
end

function Parser:ParseReturn(State, Statement)
  Statement.Kind = "Return"
  Parser:Advance(State)
  local Value = Parser:ParseExpressionList(State)
  Statement.Value = Value
end

function Parser:ParseBreak(State, Statement)
  Statement.Kind = "Break"
  Parser:Advance(State)
end

function Parser:ParseContinue(State, Statement)
  Statement.Kind = "Continue"
  Parser:Advance(State)
end

function Parser:ParseIf(State, Statement)
  if Parser.Token.Value == "elseif" then
    Statement.ElseIf = { Local = false }
    Statement = Statement.ElseIf
  end

  Statement.Kind = "If"
  Parser:Advance(State)

  local Condition = Parser:ParseExpression(State)
  Statement.Condition = Condition
  Parser:Expect(State, "Keyword", "then")

  local Body = Parser:ParseBody(State, { "end", "else", "elseif" })
  Statement.Body = Body

  if Parser.Token.Value == "end" then
    Parser:Advance(State)
  elseif Parser.Token.Value == "else" then
    Parser:Advance(State)
    local ElseBody = Parser:ParseBody(State, { "end" })
    Statement.Else = ElseBody

    Parser:Advance(State)
  else
    Parser:ParseIf(State, Statement)
    Parser:Advance(State)
  end
end

function Parser:ParseFor(State, Statement)
  Statement.Kind = "For"
  Parser:Advance(State)
  Statement.Name = Parser:ParseName(State)

  if Parser:CheckToken(State, {
    Kind = "Operator",
    Value = "=",
  }) then
    Parser:Advance(State)

    local Start = Parser:ParseExpression(State)
    Statement.Start = Start
    Parser:Expect(State, "Punct", ",")
    local Limit = Parser:ParseExpression(State)
    Statement.Limit = Limit

    if Parser:CheckToken(State, {
      Kind = "Punct",
      Value = ",",
    }) then
      Parser:Advance(State)
      Statement.Step = Parser:ParseExpression(State)
    end
  else
    Statement.KeyVariable = Statement.Name
    Statement.Name = nil

    if Parser:CheckToken(State, {
      Kind = "Punct",
      Value = ",",
    }) then
      Parser:Advance(State)
      Statement.ValueVariable = Parser.Token.Value
      Parser:Advance(State)
    end
    Parser:Expect(State, "Keyword", "in")

    local Iterator = Parser:ParseExpression(State)
    Statement.Iterator = Iterator
  end

  Parser:Expect(State, "Keyword", "do")

  local Body = Parser:ParseBody(State, { "end" })
  Parser:Advance(State)
  Statement.Body = Body
end

function Parser:ParseWhile(State, Statement)
  Statement.Kind = "While"
  Parser:Advance(State)

  local Condition = Parser:ParseExpression(State)
  Statement.Condition = Condition
  Parser:Expect(State, "Keyword", "do")

  local Body = Parser:ParseBody(State, { "end" })
  Statement.Body = Body
  Parser:Advance(State)
end

function Parser:ParseDo(State, Statement)
  Statement.Kind = "Do"
  Parser:Advance(State)

  local Body = Parser:ParseBody(State, { "end" })
  Statement.Body = Body
  Parser:Advance(State)
end

function Parser:ParseRepeat(State, Statement)
  Statement.Kind = "Repeat"
  Parser:Advance(State)

  local Body = Parser:ParseBody(State, { "until" })
  Statement.Body = Body
  Parser:Advance(State)

  local Condition = Parser:ParseExpression(State)
  Statement.Condition = Condition
end

function Parser:ParseGoto(State, Statement)
  Statement.Kind = "Goto"
  Parser:Advance(State)
  Parser:Expect(State, "Ident", nil)
  Parser:Advance(State, -1)

  local Label = Parser.Token.Value
  Statement.Name = Label
  Parser:Advance(State)
end

function Parser:ParseLabel(State, Statement)
  Statement.Kind = "Label"
  Parser:Expect(State, "Punct", "::")

  local Label = Parser.Token.Value
  Statement.Name = Label
  Parser:Advance(State)
  Parser:Expect(State, "Punct", "::")
end

function Parser:ParseStatement(State)
  local Statement = {}
  Parser.StartIndex = Parser.Index

  Statement.Local = false

  if Parser:CheckToken(State, {
    Kind = "Punct",
    Value = ";",
  }) then
    Parser:Advance(State)
    return
  elseif Parser:CheckToken(State, {
    Kind = "Ident",
  }) then
    Parser:Advance(State)

    if Parser.Token and StringHasLetter("(:", Parser.Token.Value) then
      Parser:GoToStart(State)
      Parser:ParseFunctionCall(State, Statement)
      return Statement
    elseif Parser.Token and StringHasLetter("=.,", Parser.Token.Value) then
      Parser:GoToStart(State)
      Parser:ParseVariableAssign(State, Statement)
      return Statement
    else
      Logger:Error(
        State,
        "SyntaxError",
        "Expected '(', '=', '.', or ',' after identifier but got '%s'",
        Parser.Token and Parser.Token.Value or "<EOF>"
      )
      return
    end
  elseif Parser:CheckToken(State, {
    Kind = "Punct",
    Value = "::",
  }) then
    Parser:GoToStart(State)
    Parser:ParseLabel(State, Statement)
    return Statement
  elseif Parser:CheckToken(State, {
    Kind = "Keyword",
  }) then
    if Parser.Token.Value == "local" then
      Parser:Advance(State)
      Statement = Parser:ParseStatement(State)
      Statement.Local = true

      return Statement
    elseif Parser.Token.Value == "function" then
      Parser:GoToStart(State)
      Parser:ParseFunction(State, Statement)
      return Statement
    elseif Parser.Token.Value == "return" then
      Parser:GoToStart(State)
      Parser:ParseReturn(State, Statement)
      return Statement
    elseif Parser.Token.Value == "break" then
      Parser:GoToStart(State)
      Parser:ParseBreak(State, Statement)
      return Statement
    elseif Parser.Token.Value == "continue" then
      Parser:GoToStart(State)
      Parser:ParseContinue(State, Statement)
      return Statement
    elseif Parser.Token.Value == "if" then
      Parser:GoToStart(State)
      Parser:ParseIf(State, Statement)
      return Statement
    elseif Parser.Token.Value == "for" then
      Parser:GoToStart(State)
      Parser:ParseFor(State, Statement)
      return Statement
    elseif Parser.Token.Value == "while" then
      Parser:GoToStart(State)
      Parser:ParseWhile(State, Statement)
      return Statement
    elseif Parser.Token.Value == "do" then
      Parser:GoToStart(State)
      Parser:ParseDo(State, Statement)
      return Statement
    elseif Parser.Token.Value == "repeat" then
      Parser:GoToStart(State)
      Parser:ParseRepeat(State, Statement)
      return Statement
    elseif Parser.Token.Value == "goto" then
      Parser:GoToStart(State)
      Parser:ParseGoto(State, Statement)
      return Statement
    else
      Logger:Error(State, "SyntaxError", "Expected a statement but got '%s'", Parser.Token.Value)
      return
    end
  end

  Logger:Error(State, "SyntaxError", "Expected a statement but got '%s'", Parser.Token.Value)
  return {}
end

function Parser:Reset(State)
  Parser.Token = nil
  Parser.Index = 1
  State.Ast = {}
end

function Parser:Parse(State)
  Parser:Advance(State, 0)

  while Parser.Token ~= nil do
    local Statement = Parser:ParseStatement(State)
    table.insert(State.Ast, Statement)
  end
end

function AstDesugar:Desugar(State, Ast)
  local Table = {}

  if Ast.Kind == "VariableAssign" then
    for Idx, Name in ipairs(Ast.Name) do
      local Value = Ast.Value[Idx]
      table.insert(Table, {
        Kind = "VariableAssign",
        Local = Ast.Local,
        Name = Name,
        Value = Value,
      })
    end
  elseif Ast.Kind == "For" and Ast.Start then
    Ast.Step = Ast.Step or 1

    table.insert(Ast.Body, {
      Kind = "VariableAssign",
      Name = Ast.Name,
      Value = {
        Kind = "Binary",
        Operator = "+",
        Left = Ast.Name,
        Right = {
          Kind = "Number",
          Value = 1,
        },
      },
    })

    table.insert(Table, {
      Kind = "VariableAssign",
      Local = true,
      Name = Ast.Name,
      Value = Ast.Start,
    })

    table.insert(Table, {
      Kind = "While",
      Condition = {
        Kind = "Binary",
        Operator = State.Step > 0 and "<=" or ">=",
        Left = Ast.Name,
        Right = Ast.Limit,
      },
      Body = Ast.Body,
    })
  elseif Ast.Kind == "Repeat" then
    local FirstIterationName = {
      Kind = "Identifier",
      Value = GenerateRandomName(),
    }

    table.insert(Ast.Body, {
      Kind = "VariableAssign",
      Name = FirstIterationName,
      Value = {
        Kind = "Boolean",
        Value = false,
      },
    })

    table.insert(Table, {
      Kind = "VariableAssign",
      Name = FirstIterationName,
      Value = {
        Kind = "Boolean",
        Value = true,
      },
    })

    table.insert(Table, {
      Kind = "While",
      Condition = {
        Kind = "Binary",
        Operator = "or",
        Left = {
          Kind = "Unary",
          Operator = "not",
          Operand = Ast.Condition,
        },
        Right = FirstIterationName,
      },
      Body = Ast.Body,
    })
  else
    return { Ast }
  end

  return Table
end

function AstDesugar:DesugarAst(State, Ast)
  local Idx = 1

  while Idx <= #Ast do
    local CurrentAst = Ast[Idx]
    local ExpandedAstTable = AstDesugar:Desugar(State, CurrentAst)

    if #ExpandedAstTable == 1 and ExpandedAstTable[1] == CurrentAst then
      Idx = Idx + 1
    else
      table.remove(Ast, Idx)

      for ExpandedIdx, ExpandedAst in ipairs(ExpandedAstTable) do
        table.insert(Ast, Idx, ExpandedAst)
        Idx = Idx + 1
      end
    end
  end
end

function IrGenerator:Reset(State)
  IrGenerator.Contexts = {}
  IrGenerator.Functions = {}
  IrGenerator.LabelId = 1

  State.Ir = {}
end

function IrGenerator:NewLabel(State)
  local Label = IrGenerator.LabelId
  IrGenerator.LabelId = IrGenerator.LabelId + 1

  return Label
end

function IrGenerator:PushContext(State)
  local Context = {
    Registers = {},
    IrProgram = {},
    Locals = {},
  }

  for Idx = 1, 256 do
    Context.Registers[Idx] = false
  end

  IrGenerator.Registers = Context.Registers
  IrGenerator.IrProgram = Context.IrProgram
  table.insert(IrGenerator.Contexts, Context)

  IrGenerator.Ir = {
    [1] = "NewContext",
  }
  IrGenerator:NewIr(State)
end

function IrGenerator:PopContext(State)
  local Context = table.remove(IrGenerator.Contexts)
  local Parent = IrGenerator.Contexts[#IrGenerator.Contexts]

  table.insert(Context.IrProgram, {
    [1] = "PopContext",
  })

  if Parent then
    Context.Parent = Parent
    table.insert(IrGenerator.Functions, Context)
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
  local CurrentContext = IrGenerator.Contexts[#IrGenerator.Contexts]

  for _, VariableRegister in pairs(CurrentContext.Locals) do
    if VariableRegister == Register then
      return
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

function IrGenerator:GenerateBody(State, Ast, Label, ExtraCode)
  IrGenerator:PushContext(State)

  local Context = IrGenerator.Contexts[#IrGenerator.Contexts]
  Context.Label = Label

  for _, Child in ipairs(Ast) do
    IrGenerator:Generate(State, Child)
  end

  for _, Ir in ipairs(ExtraCode or {}) do
    IrGenerator.Ir = Ir
    IrGenerator:NewIr(State)
  end

  IrGenerator:PopContext(State)
end

function IrGenerator:GenerateIdentifier(State, Ast, Data)
  if Data then
    for Idx = #IrGenerator.Contexts, 1, -1 do
      local Scope = IrGenerator.Contexts[Idx].Locals
      local VariableRegister = Scope[Ast.Name]

      if VariableRegister then
        return VariableRegister
      end
    end

    local CurrentScope = IrGenerator:GetCurrentScope(State)
    local VariableRegister = IrGenerator:AllocateRegister(State)
    CurrentScope[Ast.Name] = VariableRegister

    return VariableRegister
  else
    local ResultRegister = IrGenerator:AllocateRegister(State)
    local NameRegister = IrGenerator:Generate(State, Ast.Name)

    IrGenerator.Ir = {
      [1] = "GetVariable",
      [2] = NameRegister,
      [3] = ResultRegister,
    }
    IrGenerator:NewIr(State)
    IrGenerator:MarkNotUsed(State, NameRegister)
    return ResultRegister
  end
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

  IrGenerator.Ir = {
    [1] = "CallFunctionFromRegister",
    [2] = FunctionRegister,
  }
  IrGenerator:NewIr(State)
  IrGenerator:MarkNotUsed(State, FunctionRegister)

  IrGenerator.Ir = {
    [1] = "Pop",
    [2] = ResultRegister,
  }
  IrGenerator:NewIr(State)

  return ResultRegister
end

function IrGenerator:GenerateVariableAssign(State, Ast, Data)
  local VariableRegister = IrGenerator:Generate(State, Ast.Name, Ast.Local)
  local ValueRegister = IrGenerator:Generate(State, Ast.Value)

  IrGenerator.Ir = {
    [1] = "Copy",
    [2] = ValueRegister,
    [3] = VariableRegister,
  }
  IrGenerator:NewIr(State)
  IrGenerator:MarkNotUsed(State, VariableRegister)
  IrGenerator:MarkNotUsed(State, ValueRegister)
end

function IrGenerator:GenerateFunction(State, Ast, Data)
  local NameRegister = IrGenerator:Generate(State, Ast.Name, Ast.Local)
  local ResultRegister = IrGenerator:AllocateRegister(State)

  local FunctionLabel = IrGenerator:NewLabel(State)

  IrGenerator.Ir = {
    [1] = "CreateFunction",
    [2] = NameRegister,
    [3] = FunctionLabel,
    [4] = ResultRegister,
  }
  IrGenerator:NewIr(State)

  if Ast.Local then
    IrGenerator:MarkNotUsed(State, NameRegister)

    local CurrentScope = IrGenerator:GetCurrentScope(State)
    CurrentScope[Ast.Name] = ResultRegister
  else
    IrGenerator.Ir = {
      [1] = "SetGlobal",
      [2] = NameRegister,
      [3] = ResultRegister,
    }
    IrGenerator:NewIr(State)
    IrGenerator:MarkNotUsed(State, NameRegister)
    IrGenerator:MarkNotUsed(State, ResultRegister)
  end

  IrGenerator:GenerateBody(State, Ast.Body, FunctionLabel)
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

  IrGenerator:PushContext(State)
  local Context = IrGenerator.Contexts[#IrGenerator.Contexts]
  Context.Label = ConditionLabel

  local ConditionRegister = IrGenerator:Generate(State, Ast.Condition)

  IrGenerator.Ir = {
    [1] = "JumpIfTrue",
    [2] = ConditionRegister,
    [3] = BodyLabel,
  }
  IrGenerator:NewIr(State)
  IrGenerator:MarkNotUsed(State, ConditionRegister)
  IrGenerator:PopContext(State)

  IrGenerator:GenerateBody(State, Ast.Body, BodyLabel, {
    {
      [1] = "Jump",
      [2] = ConditionLabel,
    },
  })

  IrGenerator.Ir = {
    [1] = "Jump",
    [2] = ConditionLabel,
  }
  IrGenerator:NewIr(State)

  return ResultRegister
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
  rGenerator:MarkNotUsed(State, OperandRegister)

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

function IrGenerator:Generate(State, Ast, Data)
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
  IrGenerator:PushContext(State)

  for _, Ast in ipairs(State.Ast) do
    local ResultRegister = IrGenerator:Generate(State, Ast)

    if ResultRegister then
      IrGenerator:MarkNotUsed(State, ResultRegister)
    end
  end

  IrGenerator:PopContext(State)
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

  for _, Function in ipairs(IrGenerator.Functions) do
    State.LuaIr = State.LuaIr .. string.format("\n::Label%d::\n", Function.Label)
    GenerateBlock(Function.IrProgram)
  end
end

function Rua:Tokenize(State)
  Tokenizer:Reset(State)
  Tokenizer:Tokenize(State)
end

function Rua:Parse(State)
  Parser:Reset(State)
  Parser:Parse(State)
end

function Rua:Desugar(State)
  AstDesugar:DesugarAst(State, State.Ast)
end

function Rua:GenerateIr(State)
  IrGenerator:Reset(State)
  IrGenerator:GenerateIr(State)
end

function Rua:GenerateLuaIr(State)
  IrGenerator:GenerateLuaIr(State)
end

function Rua.new()
  return {
    File = {
      Content = "",
    },
    Tokens = {},
    Ast = {},
    Ir = {},
  }
end

function Rua:Run(State, FileName)
  local FilePtr, Error = io.open(FileName, "r")
  if not FilePtr then
    return nil, Error
  end
  State.File.Content = FilePtr:read("*a")
  State.File.Name = FileName
  FilePtr:close()

  Rua:Tokenize(State)
  PrintTable(State.Tokens)

  Rua:Parse(State)
  PrintTable(State.Ast)

  Rua:Desugar(State)
  PrintTable(State.Ast)

  Rua:GenerateIr(State)
  PrintTable(State.Ir)

  if Rua.DevMode then
    Rua:GenerateLuaIr(State)
    local IrFile = io.open("Dev.lua", "w")
    IrFile:write(State.LuaIr)
  end

  return nil, nil
end

return Rua
