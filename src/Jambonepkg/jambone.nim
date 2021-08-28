import json
import tables
import deques
import strutils
import strformat
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
  KeywordTokenKind* {.pure.} = enum
    StartExpression = "{{",
    EndExpression = "}}",
    Show = "$",
    StartBlock = "block",
    EndBlock = "endblock",
    IfBlock = "if",
    ElseBlock = "else",
    EndIfBlock = "endif"

  TokenKind* = enum
    jamKeyword,
    jamIdentifier,
    jamLiteral,
    jamComment

  Token* = object
    case kind*: TokenKind
      of jamKeyword: keyword*: KeywordTokenKind
      of jamIdentifier: identifier: string
      of jamLiteral: literal: string
      of jamComment: comment: string

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
    of jamRoot: children*: seq[JamboneASTNode]
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
      varValue: JsonNode
    of jamText:
      text: string

# TODO render partials
# proc renderPartial*

proc newKeyword*(tokenStr: string): Token =
  return Token(kind: TokenKind.jamKeyword, keyword: parseEnum[KeywordTokenKind](tokenStr))

proc isValidKeyword(str: string): bool =
  result = false

  # TODO make this hashmap.

  for t in KeywordTokenKind:
    if $t == str:
      return true

  # Check for identifier

  # TODO Check for literals
  # TODO Check for comments


proc anyKeywordContains(str: string): bool =
  result = false

  for t in KeywordTokenKind:
    if ($t).contains(str):
      return true

  # return list of candidates?

proc findExpressionToken(region: StringStream): tuple[pos: int, token: Option[Token]] =
  result = (0, none(Token))
  var tokenStr = ""

  var tokenPos = region.getPosition()
  var c = region.readChar()

  while c != '\0':
    # TODO optimize - only check against list of valid candidate tokens
    #     let candidates: seq = StartExpression[tokenPos],
    tokenStr.add(c)
    # TODO needs escaping
    if tokenStr == $KeywordTokenKind.StartExpression:
      return (pos: tokenPos, token: some(newKeyword(tokenStr)))
    if c != '{':
      tokenStr = ""
      tokenPos = region.getPosition()

    c = region.readChar()


proc findToken(region: StringStream): tuple[pos: int, token: Option[Token]] =
  result = (0, none(Token))

  var tokenStr = ""

  var tokenPos = region.getPosition()
  var c = region.readChar()

  while true:
    # TODO optimize - only check against list of valid candidate tokens
    #     let candidates: seq = StartExpression[tokenPos],
    if c == ' ' or c == '\0':
      # TODO literals
      # if c == '\'' or c == '"':
      # string literal
      # if c.isDigit
      # number literal
      # TODO comments
      if isValidKeyword(tokenStr):
        return (pos: tokenPos, token: some(newKeyword(tokenStr)))

      elif validIdentifier(tokenStr):
        return (pos: tokenPos, token: some(Token(kind: TokenKind.jamIdentifier, identifier: tokenStr)))

      else:
        if c == '\0':
          break

        tokenStr = ""
        tokenPos = region.getPosition()

    else:
      tokenStr.add(c)

    c = region.readChar()

iterator tokenizer*(cursor: StringStream): TokenOccurrence =
  # var curpos = 0
  # Are we tokenizing - somewhat of a mini optimization, don't want garbage tokens or to parse the HTML
  var tokenizingExpression = false

  while isSome((var (pos, token) = (if tokenizingExpression: findToken(cursor) else: findExpressionToken(cursor)); token)):
    let tokenVal = token.get()
    if tokenVal.kind == TokenKind.jamKeyword and tokenVal.keyword == KeywordTokenKind.StartExpression:
      tokenizingExpression = true

    elif tokenVal.kind == TokenKind.jamKeyword and tokenVal.keyword == KeywordTokenKind.EndExpression:
      tokenizingExpression = false

    yield (pos: pos, token: tokenVal)
    # curpos = pos

proc tokenize*(source: string): Deque[TokenOccurrence] =
  result = initDeque[TokenOccurrence]()

  var cursor = newStringStream(source)

  # First phase - tokenizing
  for tokenOccurrence in tokenizer(cursor):
    result.addLast(tokenOccurrence)


type ParserError = object
  # case kind: ParserErrorKind
  message: string
  lineNumber: int
  token: TokenOccurrence

proc `$`(x: ParserError): string =
  return &"Error: {x.message}\nLine number: {x.lineNumber}\n"

type ParserContextObj = object
    #stack: seq[JamboneASTNode]
    # root: JamboneASTNode
    lineNumber: int
    #node: Option[JamboneASTNode]
    activeExpression: seq[TokenOccurrence]
    error: seq[ParserError]

type ParserContext = ref ParserContextObj
# parse("...", [start token, block token, end token], )

proc parse*(currentNode: JamboneASTNode, source: StringStream, tokens: var Deque[TokenOccurrence], context: var ParserContext): JamboneASTNode =
  if len(tokens) == 0:
    return currentNode

  echo currentNode.kind

  # result = JamboneASTNode(kind: jamRoot, children: @[])
  # let stack: seq[JamboneASTNode] = @[]
  # let activeTokens: seq[TokenOccurrence] = @[]
  let token = tokens.popFirst()

  # set position to current token
  source.setPosition(token.pos)

  if token.token.kind != TokenKind.jamKeyword:
    # TODO
    return

  case token.token.keyword:
  of StartExpression:
    if len(context.activeExpression) > 0:
      context.error.add(ParserError(message: "Curly brackets not closed properly!", lineNumber: context.lineNumber, token: token))
      return

    let lineNumber = context.lineNumber
    context.activeExpression.add(token)
    # result = parse(source, tokens, context)
    # if result.isNil:
    #   context.error.add(ParserError(message: "Invalid expression:", lineNumber: lineNumber, token: token))
    #   return

    # Starting a node, pop the next token
  of EndExpression:
    if len(context.activeExpression) < 2:
      context.error.add(ParserError(message: "Empty expression or missing starting bracket", lineNumber: context.lineNumber, token: token))
      return

    context.activeExpression.setLen(0)
    # result = nil
    #node = JamboneASTNode(kind: )

  of Show:
    discard

  of StartBlock:
    # backtracking
    if len(context.activeExpression) != 1:
      context.error.add(ParserError(message: "Invalid syntax: Block", lineNumber: context.lineNumber, token: token))
      return

    context.activeExpression.add(token)
    result = JamboneASTNode(kind: JamboneASTKind.jamBlock, blockName: "")

  of EndBlock:
    discard

  of IfBlock:
    discard

  of ElseBlock:
    discard

  of EndIfBlock:
    discard


  return parse(parse(result, source, tokens, context), source, tokens, context)

proc newParseTree*(source: string, tokens: var Deque[TokenOccurrence], view: Table[string, Showable]): JamboneAstNode =
  var context = ParserContext(
    lineNumber: 0,
    # view: view,
    activeExpression: @[],
    error: @[]
  )
  # context.activeExpression = newSeq[var TokenOccurrence]()

  # Create the root node
  let root = JamboneASTNode(kind: JamboneASTKind.jamRoot, children: @[])
  let stream = newStringStream(source)
  result = parse(root, stream, tokens, context)

  if len(context.error) > 0:
    echo context.error

proc eval*(ast: JamboneASTNode): string =
  result = ""
  assert ast.kind == JamboneASTKind.jamRoot

  let output = ""
  # TODO eval AST

  result = output

let defaultConfig = %*{}

# Output to string
proc render*(source: string, view: Table[string, Showable], config: JsonNode = defaultConfig): string =
  var tokens = tokenize(source)

  echo tokens
  # Second phase -

  return "My life is like a video game, getting those TOKENS"

# , params: CompilerParams)

# Output to file
# proc compile*(source: string, context: Table[string, Showable]): string =
