-- Comments were ai-generated. comments and type
-- notation will be used to generate Rua's documentation.

local Rua = {}

---@class RuaState
---@field Tokenizer table Tokenizer instance responsible for converting source code into tokens.
---@field Parser table Parser instance responsible for parsing tokens into an abstract syntax tree.
---@field Tokens table List of tokens generated from the source file.
---@field Ast table Abstract syntax tree (AST) representing the parsed source code.

---@return RuaState State A new compiler state containing an initialized tokenizer, parser, token list, and AST.
function Rua.new()
  return {
    Tokenizer = {},
    Parser = {},
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

  local FileContent = FilePtr:read("*a")
  FilePtr:close()

  return nil, nil
end

return Rua
