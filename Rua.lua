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
  Parse Local Statement: Implemented (basic)
  Parse Function Declaration: Implemented (basic)
  Parse Expression: Implemented (basic)
  Parse Table Constructor: Implemented (basic)
  Parse Return: Implemented
  Parse Break: Implemented
  Parse If: Implemented
  Parse Else: Implemented
  Parse ElseIf: Implemented
  Parse While: Not Implemented
  Parse Repeat-Until: Not Implemented
  Parse Do Block: Not Implemented
  Parse Numeric For: Implemented
  Parse Generic For: Not Implemented
  Parse Multiple Assignment: Not Implemented
  Parse Local Variable Declaration: Partially Implemented
  Parse Local Function Declaration: Partially Implemented
  Parse Anonymous Function: Not Implemented
  Parse Method Call: Partially Implemented
  Parse Member Access: Implemented
  Parse Table Indexing: Implemented
  Parse Goto: Not Implemented
  Parse Label: Not Implemented
  Parse Empty Statement (;): Not Implemented
  Parse Semicolon Separator: Not Implemented
  Parse Vararg Expression (...): Not Implemented
  Parse Function Parameters: Partially Implemented
  Parse Multiple Return Values: Not Implemented
  Parse Unary Expression: Implemented (basic)
  Parse Binary Expression: Implemented (basic)
  Parse Parenthesized Expression: Implemented
  Parse Boolean Literal: Implemented
  Parse Nil Literal: Implemented
  Parse Number Literal: Implemented
  Parse String Literal: Implemented
  Parse Long String Literal: Not Implemented
  Parse Long Comment: Partially Implemented
  Parse Concatenation Expression: Implemented (basic)
  Parse Logical Operators (and, or): Implemented (basic)
  Parse Comparison Operators: Implemented (basic)
  Parse Arithmetic Operators: Implemented (basic)
  Parse Bitwise Operators: Partially Implemented
  Parse Floor Division Operator (//): Partially Implemented
  Parse Exponentiation Operator (^): Implemented (basic)
  Parse Function Call Expressions: Implemented (basic)
  Parse Table Field Separators (, and ;): Implemented
  Parse Nested Blocks: Partially Implemented
  Parse Block Scope: Not Implemented
  Parse Break Validation: Not Implemented
  Parse Continue Validation: Not Implemented
  Parse Syntax Error Recovery: Not Implemented
 
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
]]

---@class Rua
---@field new function
---@field Run function
---@field Tokenize function
---@field Parse function
---@field ExitOnError boolean
---@field DevMode boolean

---@type Rua
local Rua = {}

---@class RuaState
---@field Tokenizer table Tokenizer instance responsible for converting source code into tokens.
---@field Parser table Parser instance responsible for parsing tokens into an abstract syntax tree (AST).
---@field Tokens table List of tokens generated from the source file, in the order they appear.
---@field Ast table Abstract syntax tree (AST) representing the structure of the parsed source code.
---@field File RuaFile Information about the source file currently being compiled.
---@field ExitOnError boolean Whether compilation should stop when an error occurs.
---@field ErrorMessage string Error message associated with the current compilation failure.

---@class RuaLogger
---@field Error function Reports a compilation error with its type and message.

---@class RuaTokenizer
---@field Reset function Resets the tokenizer's state before tokenization.
---@field Advance function Advances through the source file by a specified number of characters.
---@field Tokenize function Converts source code into a sequence of tokens.
---@field Index integer Current character index in the source file.
---@field Character string Character currently being examined by the tokenizer.

---@class RuaParser
---@field ParseFunctionCall function
---@field Advance function
---@field Reset function
---@field Parse function
---@field Token RuaToken
---@field Index integer
---@field StartIndex integer

---@class RuaFile
---@field Name string Name or path of the source file being compiled.
---@field Content string Complete text content of the source file being compiled.
---@field Row number Current line number in the source file.
---@field Column number Current column number in the source file.

---@class RuaToken
---@field Kind string
---@field Value string|number
---@field Column number
---@field Row number

---@class RuaStatement
---@field Kind string
---@field Name RuaStatement|string
---@field Arguments RuaStatement[]

---@class AnsiTable
---@field Reset string ANSI escape sequence that resets terminal text formatting to its default.
---@field Yellow string ANSI escape sequence for yellow terminal text.
---@field Red string ANSI escape sequence for red terminal text.
---@field RuaRed string ANSI escape sequence for Rua's custom red terminal text color.
---@field LuaBlue string ANSI escape sequence for blue terminal text associated with Lua.

---@type AnsiTable
local Ansi = {
  Reset = "\27[0m",
  Yellow = "\27[33m",
  Red = "\27[31m",
  RuaRed = "\27[38;2;255;100;100m",
  LuaBlue = "\27[38;2;100;200;255m",
}

---@type RuaLogger
local Logger = {}

---@type RuaTokenizer
local Tokenizer = {}

---@type RuaParser
local Parser = {}

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

---@param Table table Table to search through.
---@param Value string String value to look for in the table.
---@return boolean Whether the table contains the specified string.
local function TableHasString(Table, Value)
  for _, Item in pairs(Table) do
    if type(Item) == "string" and Item == Value then
      return true
    end
  end

  return false
end

---@param String string String to search through.
---@param Letter string Letter or substring to look for.
---@return boolean Whether the string contains the specified letter or substring.
local function StringHasLetter(String, Letter)
  return Letter ~= "" and string.find(String, Letter, 1, true) ~= nil
end

---@param Value table Table to print.
---@param Indent? number Current indentation level.
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

---@param State RuaState Rua compiler state.
---@param ErrorType string Type or category of the error being reported.
---@param ErrorMessageFormat string Format string used to construct the error message.
---@return ErrorMessage string Formatted error message containing the source location, error type, and description.
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

  if State.ExitOnError then
    if os.exit then
      os.exit(1)
    else
      assert(false, "")
    end
  end

  return State.ErrorMessage
end

---@param State RuaState Rua compiler state.
function Tokenizer:Reset(State)
  Tokenizer.Index = 0
  Tokenizer.Character = ""
  State.File.Row = 1
  State.File.Column = 0
end

---@param State RuaState Rua compiler state.
---@param Step? number Number of characters to advance through the source file (defaults to 1).
function Tokenizer:Advance(State, Step)
  Step = Step or 1

  for _ = 1, Step do
    local Index = Tokenizer.Index + 1
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

---@param State RuaState Rua compiler state.
function Tokenizer:NewToken(State)
  Tokenizer.Token.Row = State.File.Row
  Tokenizer.Token.Column = State.File.Column

  table.insert(State.Tokens, Tokenizer.Token)
  Tokenizer.Token = {}
end

---@param State RuaState Rua compiler state.
function Tokenizer:ParseIdent(State)
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

---@param State RuaState Rua compiler state.
function Tokenizer:ParsePunct(State)
  Tokenizer.Token = {
    Kind = "Punct",
    Value = Tokenizer.Character,
  }

  Tokenizer:NewToken(State)
  Tokenizer:Advance(State)
end

---@param State RuaState Rua compiler state.
function Tokenizer:ParseNumber(State)
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

---@param State RuaState Rua compiler state.
function Tokenizer:ParseString(State)
  local StringCharacter = Tokenizer.Character
  local String = ""

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
    else
      String = String .. Tokenizer.Character
    end

    if #Tokenizer.Character == 0 then
      Logger:Error(State, "SyntaxError", "Unterminated string")
    end

    Tokenizer:Advance(State)
  end

  Tokenizer.Token = {
    Kind = "String",
    Value = String,
  }

  Tokenizer:NewToken(State)
  Tokenizer:Advance(State)
end

---@param State RuaState Rua compiler state.
function Tokenizer:ParseOperator(State)
  local IsComment, IsMultipleLineComment = false, false
  local Operator = Tokenizer.Character

  Tokenizer:Advance(State)

  if Operator == "-" and Tokenizer.Character == "-" then
    IsComment = true
    Tokenizer:Advance(State)

    if Tokenizer.Character == "[" then
      Tokenizer:Advance(State)

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
      elseif Tokenizer.Character == "]" then
        Tokenizer:Advance(State)

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

---@param State RuaState Rua compiler state.
function Tokenizer:Tokenize(State)
  Tokenizer:Advance(State)

  while #Tokenizer.Character > 0 do
    if StringHasLetter(BaseIdent, Tokenizer.Character) then
      Tokenizer:ParseIdent(State)
    elseif StringHasLetter(BasePunct, Tokenizer.Character) then
      Tokenizer:ParsePunct(State)
    elseif StringHasLetter(BaseDigits, Tokenizer.Character) then
      Tokenizer:ParseNumber(State)
    elseif Tokenizer.Character == '"' or Tokenizer.Character == "'" then
      Tokenizer:ParseString(State)
    elseif StringHasLetter(BaseOperators, Tokenizer.Character) then
      Tokenizer:ParseOperator(State)
    elseif StringHasLetter(WhiteSpace, Tokenizer.Character) then
      Tokenizer:Advance(State)
    else
      Logger:Error(State, "SyntaxError", "Unexpected character: %s", Tokenizer.Character)
      return
    end
  end
end

---@param State RuaState
---@param Kind string|string[]
---@param Value string?
---@return RuaToken|nil
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

---@param State RuaState
---@param ExpectedToken table
---@return RuaToken|nil
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

---@param State RuaState
---@param Step integer?
function Parser:Advance(State, Step)
  Step = Step or 1

  local NextIndex = Parser.Index + Step
  local Token = State.Tokens[NextIndex]
  Parser.Token = Token
  Parser.Index = NextIndex
end

---@param State RuaState
function Parser:GoToStart(State)
  local Token = State.Tokens[Parser.StartIndex]
  Parser.Index = Parser.StartIndex
  Parser.Token = Token
end

---@param State RuaState
---@return RuaToken|nil
function Parser:Peek(State, Offset)
  return State.Tokens[Parser.Index + (Offset or 1)]
end

---@param State RuaState
---@param Value string
---@return boolean
function Parser:Match(State, Value)
  if Parser.Token and Parser.Token.Value == Value then
    Parser:Advance(State)
    return true
  end

  return false
end

---@param State RuaState
---@param Value string
---@return boolean
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

---@param State RuaState
---@return table|nil
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

---@param State RuaState
---@return table|nil
function Parser:ParsePrimaryExpression(State)
  local Token = Parser.Token

  if not Token then
    Logger:Error(State, "SyntaxError", "Expected an expression")
    return nil
  end

  local Node

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
        Object = Node,
        Name = Member.Value,
      }
    elseif Parser:Match(State, "[") then
      local Index = Parser:ParseExpression(State)

      if not Index or not Parser:ExpectValue(State, "]") then
        return nil
      end

      Node = {
        Kind = "Index",
        Object = Node,
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
        Object = Node,
        Method = Method.Value,
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
        Kind = "Call",
        Callee = Node,
        Arguments = Arguments,
      }
    else
      break
    end
  end

  return Node
end

---@param State RuaState
---@param MinPrecedence? number
---@return table|nil
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

---@param State RuaState
---@param Statement RuaStatement
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

---@param State RuaState
---@param AllowedEnds string[]
---@return RuaToken[]
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

---@param State RuaState
---@param Statement RuaStatement
function Parser:ParseFunctionCall(State, Statement)
  Statement.Kind = "FunctionCall"
  Statement.Name = Parser.Token.Value
  Parser:Advance(State)

  Parser:ParseArgumentList(State, Statement)
end

---@param State RuaState
---@param Statement RuaStatement
function Parser:ParseFunction(State, Statement)
  Statement.Kind = "Function"
  Parser:Expect(State, "Keyword", "function")
  Statement.Name = Parser.Token.Value
  Parser:Advance(State)
  Parser:ParseArgumentList(State, Statement)

  local Body = Parser:ParseBody(State, { "end" })
  Statement.Body = Body
  Parser:Advance(State)
end

---@param State RuaState
---@param Statement RuaStatement
function Parser:ParseVariableAssign(State, Statement)
  Statement.Kind = "VariableAssign"
  Statement.Name = Parser.Token.Value
  Parser:Advance(State, 2)
  local Value = Parser:ParseExpression(State)
  Statement.Value = Value
end

---@param State RuaState
---@param Statement RuaStatement
function Parser:ParseReturn(State, Statement)
  Statement.Kind = "Return"
  Parser:Advance(State)
  local Value = Parser:ParseExpression(State)
  Statement.Value = Value
end

---@param State RuaState
---@param Statement RuaStatement
function Parser:ParseBreak(State, Statement)
  Statement.Kind = "Break"
  Parser:Advance(State)
end

---@param State RuaState
---@param Statement RuaStatement
function Parser:ParseContinue(State, Statement)
  Statement.Kind = "Continue"
  Parser:Advance(State)
end

---@param State RuaState
---@param Statement RuaStatement
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
    print(Statement.ElseIf)
    Parser:Advance(State)
  end
end

---@param State RuaState
---@param Statement RuaStatement
function Parser:ParseFor(State, Statement)
  Statement.Kind = "For"
  Parser:Advance(State)
  Statement.Name = Parser.Token.Value
  Parser:Advance(State)
  Parser:Expect(State, "Operator", "=")

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

  Parser:Expect(State, "Keyword", "do")

  local Body = Parser:ParseBody(State, { "end" })
  Parser:Advance(State)
  Statement.Body = Body
end

---@param State RuaState
---@return RuaStatement
function Parser:ParseStatement(State)
  local Statement = {}
  Parser.StartIndex = Parser.Index

  Statement.Local = false

  if Parser:CheckToken(State, {
    Kind = "Ident",
  }) then
    Parser:Advance(State)

    if Parser.Token.Value == "(" then
      Parser:GoToStart(State)
      Parser:ParseFunctionCall(State, Statement)
      return Statement
    elseif Parser.Token.Value == "=" then
      Parser:GoToStart(State)
      Parser:ParseVariableAssign(State, Statement)
      return Statement
    else
      Logger:Error(State, "SyntaxError", "Expected '(' or '=' after Identifier but got '%s'", Parser.Token.Value)
      return
    end
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
    else
      Logger:Error(
        State,
        "SyntaxError",
        "Expected 'local', 'function', 'return', 'break', 'continue', 'if', or 'for' but got '%s'",
        Parser.Token.Value
      )
      return
    end
  end

  Logger:Error(State, "SyntaxError", "Expected a statement but got '%s'", Parser.Token.Value)
  return {}
end

---@param State RuaState
function Parser:Reset(State)
  Parser.Token = nil
  Parser.Index = 1
end

---@param State RuaState
function Parser:Parse(State)
  Parser:Advance(State, 0)

  while Parser.Token ~= nil do
    local Statement = Parser:ParseStatement(State)
    table.insert(State.Ast, Statement)
  end
end

---@param State RuaState Rua compiler state containing the tokenizer, parser, tokens, and AST.
function Rua:Tokenize(State)
  Tokenizer:Reset(State)
  Tokenizer:Tokenize(State)
end

---@param State RuaState Rua compiler state containing the tokenizer, parser, tokens, and AST.
function Rua:Parse(State)
  Parser:Reset(State)
  Parser:Parse(State)
end

---@return RuaState State A new compiler state containing an initialized tokenizer, parser, token list, and AST.
function Rua.new()
  return {
    File = {
      Content = "",
    },
    Tokenizer = {
      Index = 0,
      Character = "",
      Token = {},
    },
    Parser = {
      Token = {},
    },
    Tokens = {},
    Ast = {},
  }
end

--- Runs the Rua compiler on a source file.
--- Reads the source file, tokenizes its contents, and parses the resulting tokens.
---@param State RuaState Rua compiler state containing the tokenizer, parser, tokens, and AST.
---@param FileName string Path to the source file to compile.
---@return string|nil Result Generated output if compilation succeeds, or nil if an error occurs.
---@return string|nil Error Error message describing the failure, or nil if compilation succeeds.
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

  return nil, nil
end

return Rua
