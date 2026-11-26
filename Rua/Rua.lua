--[[
  Rua, A Lua compiler written entirely in Lua.
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
  Generate Local Statement: Implemented
  Generate Function Declaration: Implemented
  Generate Return: Implemented
  Generate Break: Implemented
  Generate Method Call: Implemented
  Generate Numeric For: Implemented
  Generate Generic For: Implemented
  Generate If: Implemented
  Generate While: Implemented
  Generate Expression: Implemented
  Generate Binary Expression: Implemented
  Generate Unary Expression: Implemented
  Generate Identifier: Implemented
  Generate Number Literal: Implemented
  Generate String Literal: Implemented
  Generate Boolean Literal: Implemented
  Generate Nil Literal: Implemented
  Generate Table Constructor: Implemented
  Generate Table Indexing: Implemented
  Generate Member Access: Implemented
  Generate Anonymous Function: Implemented
  Generate Labels: Implemented
]]

local Rua = {}
Rua.Version = "0.2.0" -- TODO: Need to bump version

local Ansi = {
  Reset = "\27[0m",
  Yellow = "\27[33m",
  Red = "\27[31m",
  RuaRed = "\27[38;2;255;100;100m",
  LuaBlue = "\27[38;2;100;200;255m",
}

local Logger = {}
_G.Logger = Logger

local FrontEnd = require("Rua.FrontEnd")
local Tokenizer = FrontEnd.Tokenizer
local Parser = FrontEnd.Parser
local AstDesugar = FrontEnd.AstDesugar
local IrGenerator = FrontEnd.IrGenerator
local LuaIrGenerator = FrontEnd.LuaIrGenerator

function Logger:PrintTable(Value, Indent)
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
      Logger:PrintTable(Item, Indent + 1)
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

  if Rua._DevMode then
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
  LuaIrGenerator:Generate(State)
end

function Rua.new()
  local State = {
    File = {
      Content = "",
    },
    Tokens = {},
    Ast = {},
    Ir = {},
  }

  return State
end

function Rua:Compile(State, FileName, OutputFile, Arguments)
  local FilePtr, Error = io.open(FileName, "r")
  if not FilePtr then
    return nil, Error
  end
  State.File.Content = FilePtr:read("*a")
  State.File.Name = FileName
  FilePtr:close()

  Rua:Tokenize(State)
  if Rua._DevMode then
    Logger:PrintTable(State.Tokens)
  end

  Rua:Parse(State)
  if Rua._DevMode then
    Logger:PrintTable(State.Ast)
  end

  Rua:Desugar(State)
  if Rua._DevMode then
    Logger:PrintTable(State.Ast)
  end

  Rua:GenerateIr(State)
  if Rua._DevMode then
    Rua:GenerateLuaIr(State)

    local IrFile = io.open("Dev/Ir.lua", "w")
    IrFile:write(State.LuaIr)
    IrFile:close()
  end
end

return Rua
