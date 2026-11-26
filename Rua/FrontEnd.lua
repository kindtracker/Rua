local IrGenerators = require("Rua.IrGenerator")
local IrGenerator = IrGenerators.IrGenerator
local LuaIrGenerator = IrGenerators.LuaIrGenerator

local Tokenizer = {}
local Parser = {}
local AstDesugar = {}
local Logger = _G.Logger

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

local function GenerateRandomName()
  local Characters = BaseIdent .. BaseDigits
  local Result = {}

  for Idx = 1, 16 do
    local RandomIndex = math.random(#Characters)
    Result[Idx] = Characters:sub(RandomIndex, RandomIndex)
  end

  return "__Rua_" .. table.concat(Result)
end

function Tokenizer:Reset(State)
  Tokenizer.Index = 0
  Tokenizer.Character = ""
  State.File.Row = 1
  State.File.Column = 0
  Tokenizer.StartRow = 1
  Tokenizer.StartColumn = 1
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
      State.File.Row = State.File.Row + Direction
      State.File.Column = 0
    else
      State.File.Column = State.File.Column + Direction
    end
  end
end

function Tokenizer:NewToken(State)
  Tokenizer.Token.Row = Tokenizer.StartRow
  Tokenizer.Token.Column = Tokenizer.StartColumn
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
    local Opening = State.File.Content:sub(Tokenizer.Index)
    if Opening:match("^%[(=*)%[") then
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
  local Content = State.File.Content
  local StartCharacter = Tokenizer.Character
  local String = ""
  local IsMultipleLineString = false
  local StringLevel = 0

  if StartCharacter == "[" then
    local Opening = Content:sub(Tokenizer.Index)
    local Equals = Opening:match("^%[(=*)%[")

    if Equals ~= nil then
      IsMultipleLineString = true
      StringLevel = #Equals

      for _ = 1, StringLevel + 2 do
        Tokenizer:Advance(State)
      end

      if Tokenizer.Character == "\n" then
        Tokenizer:Advance(State)
      end
    else
      Tokenizer.Token = {
        Kind = "Punct",
        Value = "[",
      }

      Tokenizer:NewToken(State)
      Tokenizer:Advance(State)
      return
    end
  else
    Tokenizer:Advance(State)
  end

  while #Tokenizer.Character > 0 do
    if IsMultipleLineString then
      if Tokenizer.Character == "]" then
        local Closing = "]" .. string.rep("=", StringLevel) .. "]"
        local Current = Content:sub(Tokenizer.Index, Tokenizer.Index + #Closing - 1)

        if Current == Closing then
          for _ = 1, #Closing do
            Tokenizer:Advance(State)
          end

          break
        end
      end

      String = String .. Tokenizer.Character
      Tokenizer:Advance(State)
    else
      if Tokenizer.Character == StartCharacter then
        Tokenizer:Advance(State)
        break
      elseif Tokenizer.Character == "\n" then
        Logger:Error(State, "SyntaxError", "Unterminated string")
        return
      elseif Tokenizer.Character == "\\" then
        Tokenizer:Advance(State)

        if #Tokenizer.Character == 0 then
          Logger:Error(State, "SyntaxError", "Unterminated escape sequence")
          return
        end

        local Escape = BaseEscapes[Tokenizer.Character]

        if Escape ~= nil then
          String = String .. Escape
          Tokenizer:Advance(State)
        elseif StringHasLetter(BaseDigits, Tokenizer.Character) then
          local NumberString = ""

          for _ = 1, 3 do
            if not StringHasLetter(BaseDigits, Tokenizer.Character) then
              break
            end

            NumberString = NumberString .. Tokenizer.Character
            Tokenizer:Advance(State)
          end

          local Number = tonumber(NumberString)

          if Number > 255 then
            Logger:Error(State, "SyntaxError", "Decimal escape too large: %s", NumberString)
            return
          end

          String = String .. string.char(Number)
        else
          Logger:Error(State, "SyntaxError", "Invalid escape sequence: \\%s", Tokenizer.Character)
          return
        end
      else
        String = String .. Tokenizer.Character
        Tokenizer:Advance(State)
      end
    end
  end

  if #Tokenizer.Character == 0 then
    Logger:Error(State, "SyntaxError", "Unterminated string")
    return
  end

  Tokenizer.Token = {
    Kind = "String",
    Value = String,
  }

  Tokenizer:NewToken(State)
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
    Tokenizer.StartRow = State.File.Row
    Tokenizer.StartColumn = State.File.Column

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
      Tokenizer:Advance(State)
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
        Kind = "Member",
        Table = Node,
        Name = Index,
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
      Statement.ValueVariable = Parser:ParseName(State)
    end
    Parser:Expect(State, "Keyword", "in")

    local IteratorFactory = Parser:ParseExpression(State)
    Statement.IteratorFactory = IteratorFactory
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

function Parser:ParseStatement(State)
  local Statement = {}
  Parser.StartIndex = Parser.Index

  Statement.Local = false
  Statement.Row = Parser.Token.Row

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

function AstDesugar:DesugarFor(State, Ast, Table)
  Ast.Step = Ast.Step or 1

  table.insert(Ast.Body, {
    Kind = "VariableAssign",
    Name = {
      Ast.Name,
    },
    Local = true,
    Value = {
      {
        Kind = "Binary",
        Operator = "+",
        Left = Ast.Name,
        Right = {
          Kind = "Number",
          Value = 1,
        },
      },
    },
  })

  table.insert(Table, {
    Kind = "VariableAssign",
    Local = true,
    Name = {
      Ast.Name,
    },
    Value = {
      Ast.Start,
    },
  })

  table.insert(Table, {
    Kind = "While",
    Condition = {
      Kind = "Binary",
      Operator = Ast.Step > 0 and "<=" or ">=",
      Left = Ast.Name,
      Right = Ast.Limit,
    },
    Body = Ast.Body,
  })
end

function AstDesugar:DesugarRepeat(State, Ast, Table)
  local FirstIterationName = {
    Kind = "Identifier",
    Name = GenerateRandomName(),
  }

  table.insert(Ast.Body, {
    Kind = "VariableAssign",
    Name = {
      FirstIterationName,
    },
    Value = {
      Kind = "Boolean",
      Value = false,
    },
  })

  table.insert(Table, {
    Kind = "VariableAssign",
    Name = {
      FirstIterationName,
    },
    Value = {
      {
        Kind = "Boolean",
        Value = true,
      },
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
end

function AstDesugar:DesugarDo(State, Ast, Table)
  table.insert(Table, {
    Kind = "If",
    Condition = {
      Kind = "Boolean",
      Value = true,
    },
    Body = Ast.Body,
  })
end

function AstDesugar:DesugarFunctionCall(State, Ast, Table)
  local Arguments = {}

  if Ast.Name.Separator == ":" then
    table.insert(Arguments, Ast.Name.Table)
  end

  for _, Argument in ipairs(Ast.Arguments) do
    table.insert(Arguments, Argument)
  end

  table.insert(Table, {
    Kind = "FunctionCall",
    Local = false,
    Name = Ast.Name,
    Arguments = Arguments,
  })
end

function AstDesugar:DesugarGenericFor(State, Ast, Table)
  local IteratorName = {
    Kind = "Identifier",
    Name = GenerateRandomName(),
  }

  local StateName = {
    Kind = "Identifier",
    Name = GenerateRandomName(),
  }

  local ControlName = {
    Kind = "Identifier",
    Name = GenerateRandomName(),
  }

  table.insert(Table, {
    Kind = "VariableAssign",
    Local = true,
    Name = {
      IteratorName,
      StateName,
      ControlName,
    },
    Value = { Ast.IteratorFactory },
  })

  local WhileBody = {
    Kind = "While",
    Local = false,
    Condition = {
      Kind = "Boolean",
      Value = true,
    },
    Body = {
      {
        Kind = "VariableAssign",
        Local = true,
        Name = {
          Ast.KeyVariable,
          Ast.ValueVariable,
        },
        Value = {
          {
            Kind = "FunctionCall",
            Local = false,
            Arguments = {
              StateName,
              ControlName,
            },
            Name = IteratorName,
          },
        },
      },
      {
        Kind = "If",
        Local = false,
        Condition = {
          Kind = "Binary",
          Operator = "==",
          Left = Ast.KeyVariable,
          Right = {
            Kind = "Nil",
          },
        },
        Body = {
          {
            Kind = "Break",
            Local = false,
          },
        },
      },
      {
        Kind = "VariableAssign",
        Local = false,
        Name = {
          ControlName,
        },
        Value = {
          Ast.KeyVariable,
        },
      },
    },
  }

  table.insert(Table, WhileBody)

  for _, Child in ipairs(Ast.Body) do
    table.insert(WhileBody.Body, Child)
  end
end

function AstDesugar:DesugarIf(State, Ast, Table)
  local Current = Ast

  while Current.ElseIf do
    Current.Else = {
      {
        Kind = "If",
        Condition = Current.ElseIf.Condition,
        Body = Current.ElseIf.Body,
      },
    }

    Current.ElseIf = nil
    Current = Current.Else[1]
  end

  table.insert(Table, Ast)
end

function AstDesugar:Desugar(State, Ast)
  local Table = {}

  if Ast.Body then
    AstDesugar:DesugarAst(State, Ast.Body)
  end

  if Ast.Kind == "For" and Ast.Start then
    AstDesugar:DesugarFor(State, Ast, Table)
  elseif Ast.Kind == "For" and not Ast.Start then
    AstDesugar:DesugarGenericFor(State, Ast, Table)
  elseif Ast.Kind == "Repeat" then
    AstDesugar:DesugarRepeat(State, Ast, Table)
  elseif Ast.Kind == "Do" then
    AstDesugar:DesugarDo(State, Ast, Table)
  elseif Ast.Kind == "FunctionCall" and Ast.Name.Kind == "Member" then
    AstDesugar:DesugarFunctionCall(State, Ast, Table)
  elseif Ast.Kind == "If" then
    AstDesugar:DesugarIf(State, Ast, Table)
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

return {
  Tokenizer = Tokenizer,
  Parser = Parser,
  AstDesugar = AstDesugar,
  IrGenerator = IrGenerator,
  LuaIrGenerator = LuaIrGenerator,
}
