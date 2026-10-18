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

---@param Table table Table to search through.
---@param Value string String value to look for in the table.
---@return boolean Whether the table contains the specified string.
function TableHasString(Table, Value)
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
function StringHasLetter(String, Letter)
  return string.find(String, Letter, 1, true) ~= nil
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

---@class RuaFile
---@field Content string Complete text content of the source file being compiled.

---@class RuaTokenizer
---@field Reset function
---@field Advance function
---@field Tokenize function
---@field Index integer
---@field Character string

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

---@type RuaTokenizer
local Tokenizer = {}

---@param State RuaState Rua compiler state.
function Tokenizer:Reset(State)
  Tokenizer.Index = 0
  Tokenizer.Character = ""
end

---@param State RuaState Rua compiler state.
function Tokenizer:Advance(State)
  local Index = Tokenizer.Index + 1
  Tokenizer.Character = State.File.Content:sub(Index, Index)
  Tokenizer.Index = Index
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
    else
      print(string.format("Unknown token: %s", Tokenizer.Character))
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
  FilePtr:close()

  Rua:Tokenize(State)

  PrintTable(State.Tokens)

  return nil, nil
end

return Rua
