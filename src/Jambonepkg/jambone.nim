import json
import tables
import strutils
import streams
import options

# type
#   CompilerParams* = object
# Partials = seq[tuple(name: string, ...)]


type
  Showable* = concept x
    $(x) is string


# TODO functions FunctionNameToken, FunctionStartParamsToken, FunctionEndParamsToken, FunctionParamToken,
type
  Token* {.pure.} = enum
    StartExpression = "{{",
    EndExpression = "}}",
    Show = "$",
    StartBlock = "block",
    EndBlock = "endblock",
    IfBlock = "if",
    ElseBlock = "else",
    EndIfBlock = "endif"

  TokenOccurrence* = tuple[pos: int, token: Token]

# let maxTokenLength =

  JamboneASTKind = enum
    jamRoot, # Base/root node of AST
    # Example:
    # {{if this}} sietnarietn {{ $variable }} {{endif}}
    # jamRoot -> [jamText, jamVariable, jamText]
    jamBlock,
    jamIf,
    jamShow,
    jamVariable,
    jamText

  JamboneASTNode = ref object
    case kind: JamboneASTKind
    of jamRoot: children: seq[JamboneASTNode]
    of jamBlock:
      blockName: string
      contents: JamboneASTNode
    of jamIf:
      condition, ifContents, elseContents: JamboneASTNode
      # elseifBranches seq[JamboneASTNode]
    of jamShow:
      variable: JamboneASTNode
    of jamVariable:
      varName: string
      varValue: Showable
    of jamText:
      text: string

# TODO render partials
# proc renderPartial*

proc isToken(str: string): bool =
  result = false

  for t in Token:
    if $t == str:
      return true

proc anyTokenContains(str: string): bool =
  result = false

  for t in Token:
    if ($t).contains(str):
      return true

  # return list of candidates?

proc findToken(region: StringStream): tuple[pos: int, token: Option[Token]] =
  result = (0, none(Token))

  var tokenStr = ""

  var tokenPos = region.getPosition()
  var c = region.readChar()

  while c != '\0':
    tokenStr.add(c)
    if not anyTokenContains(tokenStr):
      tokenStr = ""
      tokenPos = region.getPosition()
      c = region.readChar()
      continue

    # TODO optimize - only check against list of valid candidate tokens
    #     let candidates: seq = StartExpression[tokenPos],

    if isToken(tokenStr):
      return (pos: tokenPos, token: some(parseEnum[Token](tokenStr)))

    c = region.readChar()
    # tokenPos += 1

iterator tokenizer*(cursor: StringStream): TokenOccurrence =
  # var curpos = 0
  while isSome((var (pos, token) = findToken(cursor); token)):
    yield (pos: pos, token: token.get())
    # curpos = pos


proc parse*(source: string, tokens: seq[TokenOccurrence], context: Table[string, Showable]): JamboneASTNode =
  result = JamboneASTNode(kind: jamRoot, children: @[])


proc eval*(ast: JamboneASTNode): string =
  result = ""
  assert ast.kind == JamboneASTKind.jamRoot

  let output = ""
  # TODO eval AST

  result = output

let defaultConfig = %*{}

# Output to string
proc render*(source: string, context: Table[string, Showable], config: JsonNode = defaultConfig): string =
  var tokens = newSeq[TokenOccurrence]()

  var cursor = newStringStream(source)

  # First phase - tokenizing
  for tokenOccurrence in tokenizer(cursor):
    tokens.add(tokenOccurrence)

  echo tokens
  # Second phase -

  return "My life is like a video game, getting those TOKENS"

# , params: CompilerParams)

# Output to file
# proc compile*(source: string, context: Table[string, Showable]): string =
