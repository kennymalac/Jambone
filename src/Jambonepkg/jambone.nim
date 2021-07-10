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

# let maxTokenLength =

  # TokenObject = object
  #   pos: int

  #   case kind: Token
  #   of StartExpression:
  #   of EndExpression:
  #   of Show:
  #   of StartBlock:
  #   of EndBlock:
  #     of IfBlock:
  #   of ElseBlock:
  #   of EndIfBlock:

type
  TokenOccurrence* = tuple[pos: int, token: Token]

# TODO render partials
# proc renderPartial*

proc isToken(str: string): bool =
  result = false

  for t in Token:
    if $t == str:
      return true

proc findToken(region: StringStream): tuple[pos: int, token: Option[Token]] =
  result = (0, none(Token))

  var tokenStr = ""
  var tokenPos = 0

  var c = region.readChar()
  while c != '\0':
    if Whitespace.contains(c):
      tokenStr = ""
      tokenPos = region.getPosition()
      c = region.readChar()
      continue

    tokenStr.add(c)

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
