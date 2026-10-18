-- Comments were ai-generated. comments and type
-- notation will be used to generate Rua's documentation.

local Rua = {}

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
    io.write(tostring(Key) .. " = ")

    if type(Item) == "table" then
      io.write("{\n")
      PrintTable(Item, Indent + 1)
      io.write(string.rep("  ", Indent) .. "}\n")
    else
      io.write(tostring(Item) .. "\n")
    end
  end
end

---@class RuaState
---@field Tokenizer table Tokenizer instance responsible for converting source code into tokens.
---@field Parser table Parser instance responsible for parsing tokens into an abstract syntax tree (AST).
---@field Tokens table List of tokens generated from the source file, in the order they appear.
---@field Ast table Abstract syntax tree (AST) representing the structure of the parsed source code.
---@field File RuaFile Information about the source file currently being compiled.
---@field ExitOnError boolean
---@field ErrorMessage string

---@class RuaFile
---@field Name string
---@field Content string Complete text content of the source file being compiled.
---@field Row number
---@field Column number

---@class RuaTokenizer
---@field Reset function
---@field Advance function
---@field Tokenize function
---@field Index integer
---@field Character string

---@class RuaLogger
---@field Error function

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
    Parser = {},
    Tokens = {},
    Ast = {},
  }
end

---@class AnsiTable
---@field Reset string
---@field Yellow string
---@field Red string
---@field RuaRed string
---@field LuaBlue string

local Ansi = {
  Reset = "\27[0m",
  Yellow = "\27[33m",
  Red = "\27[31m",
  RuaRed = "\27[38;2;255;100;100m",
  LuaBlue = "\27[38;2;100;200;255m",
}

---@type RuaLogger
local Logger = {}

---@param State RuaState
---@param ErrorType string
---@param ErrorMessageFormat string
---@return ErrorMessage string
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

---@type RuaTokenizer
local Tokenizer = {}

---@param State RuaState Rua compiler state.
function Tokenizer:Reset(State)
  Tokenizer.Index = 0
  Tokenizer.Character = ""
  State.File.Row = 1
  State.File.Column = 0
end

---@param State RuaState Rua compiler state.
---@param Step? number
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
  table.insert(State.Tokens, Tokenizer.Token)
  Tokenizer.Token = {}
end

---@param State RuaState Rua compiler state.
function Tokenizer:Tokenize(State)
  Tokenizer:Advance(State)
  while true do
    if StringHasLetter(BaseIdent, Tokenizer.Character) then
      local StartIndex = Tokenizer.Index

      while StringHasLetter(BaseIdent, Tokenizer.Character) do
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
    elseif StringHasLetter(BasePunct, Tokenizer.Character) then
      Tokenizer.Token = {
        Type = "Punct",
        Value = Tokenizer.Character,
      }
      Tokenizer:NewToken(State)
      Tokenizer:Advance(State)
    elseif StringHasLetter(BaseDigits, Tokenizer.Character) then
      local StartIndex = Tokenizer.Index

      while StringHasLetter(BaseDigits, Tokenizer.Character) do
        Tokenizer:Advance(State)
      end

      local EndIndex = Tokenizer.Index - 1
      local Number = State.File.Content:sub(StartIndex, EndIndex)
      Number = tonumber(Number)
      Tokenizer.Token = {
        Type = Type,
        Value = Number,
      }
      Tokenizer:NewToken(State)
    elseif Tokenizer.Character == '"' or Tokenizer.Character == "'" then
      local StringCharacter = Tokenizer.Character
      Tokenizer:Advance(State)
      local StartIndex = Tokenizer.Index

      while Tokenizer.Character ~= StringCharacter do
        Tokenizer:Advance(State)
      end

      local EndIndex = Tokenizer.Index - 1
      local String = State.File.Content:sub(StartIndex, EndIndex)
      Tokenizer.Token = {
        Type = "String",
        Value = String,
      }
      Tokenizer:NewToken(State)
      Tokenizer:Advance(State)
    elseif StringHasLetter(BaseOperators, Tokenizer.Character) then
      local IsComment, IsMultipleLineComment = false, false
      local Operator = Tokenizer.Character

      Tokenizer:Advance(State)
      if Tokenizer.Character == "-" then
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
          Operator = Operator .. "="
          Tokenizer:Advance(State)
        end
      end

      if IsComment then
        while true do
          if not IsMultipleLineComment then
            if Tokenizer.Character == "\n" then
              break
            end
          else
            if Tokenizer.Character == "]" then
              Tokenizer:Advance(State)
              if Tokenizer.Character == "]" then
                Tokenizer:Advance(State)
                break
              end
            end
          end

          Tokenizer:Advance(State)
        end
      else
        Tokenizer.Token = {
          Type = "Operator",
          Value = Operator,
        }
        Tokenizer:NewToken(State)
        Tokenizer:Advance(State)
      end
    elseif StringHasLetter(WhiteSpace, Tokenizer.Character) then
      Tokenizer:Advance(State)
    elseif #Tokenizer.Character == 0 then
      break
    else
      Logger:Error(State, "SyntaxError", "Unexpected character: %s", Tokenizer.Character)
      break
    end
  end
end

---@param State RuaState Rua compiler state containing the tokenizer, parser, tokens, and AST.
function Rua:Tokenize(State)
  Tokenizer:Reset(State)
  Tokenizer:Tokenize(State)
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

  return nil, nil
end

return Rua
