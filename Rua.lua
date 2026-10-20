-- Comments were ai-generated. comments and type
-- notation will be used to generate Rua's documentation.

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

---@class RuaFile
---@field Name string Name or path of the source file being compiled.
---@field Content string Complete text content of the source file being compiled.
---@field Row number Current line number in the source file.
---@field Column number Current column number in the source file.

---@class RuaToken
---@field Type string
---@field Value string|number
---@field Column number
---@field Row number

---@class RuaStatement
---@field Kind string

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
    io.write(string.format("%s = ", Key))

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
  local Type = TableHasString(BaseKeywords, Ident) and "Keyword" or "Ident"

  Tokenizer.Token = {
    Type = Type,
    Value = Ident,
  }

  Tokenizer:NewToken(State)
end

---@param State RuaState Rua compiler state.
function Tokenizer:ParsePunct(State)
  Tokenizer.Token = {
    Type = "Punct",
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
    Type = "Number",
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
    Type = "String",
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
      Type = "Operator",
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
---@param Type string|string[]
---@param Value string?
---@return RuaToken|nil
function Parser:Expect(State, Type, Value)
  local Token = Parser.Token

  local ValidType = false

  if Token then
    if type(Type) == "table" then
      ValidType = TableHasString(Type, Token.Type)
    else
      ValidType = Token.Type == Type
    end
  end

  if not Token or not ValidType or (Value ~= nil and Token.Value ~= Value) then
    Logger:Error(State, "SyntaxError", "Unexpected token '%s'", Token and Token.Value or "EOF")
    return nil
  end

  Parser:Advance(State)
  return Token
end

---@param State RuaState
---@param Step number?
function Parser:Advance(State, Step)
  Step = Step or 1

  local NextIndex = Parser.Index + Step
  local Token = State.Tokens[NextIndex]
  Parser.Token = Token
  Parser.Index = NextIndex
end

---@param State RuaState
---@param Statement RuaStatement
function Parser:ParseFunctionCall(State, Statement)
  Statement.Kind = "FunctionCall"
  Statement.Name = Parser.Token.Value
  Parser:Advance(State)

  Statement.Arguments = {}
  while true do
    Parser:Advance(State)

    if Parser.Token.Type == "Punct" and Parser.Token.Value == ")" then
      break
    end

    local Argument = Parser.Token.Value
    table.insert(Statement.Arguments, Argument)
  end
  Parser:Advance(State)
end

---@param State RuaState
---@return RuaStatement
function Parser:ParseStatement(State)
  local Statement = {}
  local StartIndex = Parser.Index

  if Parser.Token.Type == "Ident" then
    Parser:Advance(State)

    if not Parser:Expect(State, "Punct", "(") then
      return
    end
    Parser:Advance(State, -1)

    if Parser.Token.Value == "(" then
      Parser.Index = StartIndex
      Parser.Token = State.Tokens[StartIndex]
      Parser:ParseFunctionCall(State, Statement)
      return Statement
    end
  end

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
