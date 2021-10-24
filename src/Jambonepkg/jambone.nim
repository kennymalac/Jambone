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

  JamboneASTKind* = enum
    jamRoot, # Base/root node of AST
    # Example:
    # {{if this}} sietnarietn {{ $variable }} {{endif}}
    # jamRoot -> [jamText, jamVariable, jamText]
    jamBlock,
    # NOTE Implementation detail: End terminates if, block, etc.
    jamEnd,
    jamIf,
    jamShow,
    jamVariable,
    jamText

  JamboneASTNode = ref object
    # TODO add parent
    case kind*: JamboneASTKind
    of jamRoot: children*: seq[JamboneASTNode]
    of jamBlock:
      blockName*: string
      contents*: JamboneASTNode
    of jamEnd: discard
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

proc `$`*(x: JamboneASTNode): string =
  case x.kind:
    of jamRoot:
      return &"{x.kind} {len(x.children)} children"
    of jamBlock:
      return &"{x.kind} blockName: {x.blockName}"
    of jamEnd:
       return "END"
    of jamIf:
      return &"{x.kind} condition: {x.condition} ifContents: {x.ifContents} {x.elseContents}"
      # elseifBranches seq[JamboneASTNode]
    of jamShow:
      return &"{x.kind} show: {x.variable}"
    of jamVariable:
      return &"{x.kind} varName: {x.varName}\nvarValue: {x.varValue}"
    of jamText:
      return &"{x.kind} text: {x.text}"


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
  token: Option[TokenOccurrence]

proc `$`*(x: ParserError): string =
  return &"Error: {x.message}\nLine number: {x.lineNumber}\n"

type ParserContextObj = object
    #stack: seq[JamboneASTNode]
    lineNumber: int
    #node: Option[JamboneASTNode]
    activeExpression: seq[TokenOccurrence]
    error: seq[ParserError]

type ParserContext = ref ParserContextObj
# parse("...", [start token, block token, end token], )

proc match*(currentNode: JamboneASTNode, tokens: var Deque[TokenOccurrence], context: var ParserContext): JamboneASTNode =
  if len(tokens) == 0:
    return currentNode

  let token = tokens.popFirst()
  #source.setPosition(token.pos)
  echo token

  if token.token.kind == TokenKind.jamIdentifier:
    if len(context.activeExpression) == 0:
      #context.warning.add(ParserWarning
      echo "Parser warning: Lone identifier token outside of expression, tokenizer pfucked up, something could go wrong.\n"

    elif len(context.activeExpression) == 1:
      # Must be a functional call.
      # TODO functions
      context.error.add(ParserError(message: "Lone identifier, functions not implemented", lineNumber: context.lineNumber, token: some(token)))
      return

    if currentNode == nil:
      context.error.add(ParserError(message: "Identifier is inside an empty expression. To echo a variable, please use $.", lineNumber: context.lineNumber, token: some(token)))

    let identifier = token.token.identifier

    if currentNode.kind == JamboneASTKind.jamBlock:
      currentNode.blockName = identifier
    #elif currentNode.kind == JamboneASTKind.jamIf:
    #  currentNode.condition = identifier
    elif currentNode.kind == JamboneASTKind.jamShow:
      # TODO grab variable from context
      currentNode.variable = JamboneASTNode(kind: JamboneASTKind.jamVariable, varName: identifier, varValue: nil)

    else:
      # TODO figure out if it's a variable or if it's text
      context.error.add(ParserError(message: "Variable is inside an empty expression. To echo a variable, please use $.", lineNumber: context.lineNumber, token: some(token)))

    echo ")"
    # return
    return match(currentNode, tokens, context)

  # Keyword
  case token.token.keyword:
  of StartExpression:
    if len(context.activeExpression) > 0:
      context.error.add(ParserError(message: "Curly brackets not closed properly!", lineNumber: context.lineNumber, token: some(token)))
      return

    let lineNumber = context.lineNumber
    context.activeExpression.add(token)

    return match(nil, tokens, context)

    # result = parse(source, tokens, context)
    # if result.isNil:
    #   context.error.add(ParserError(message: "Invalid expression:", lineNumber: lineNumber, token: token))
    #   return
    #return parse(result, source, tokens, context)

    # Starting a node, pop the next token
  of EndExpression:
    if len(context.activeExpression) < 1:
      context.error.add(ParserError(message: "Empty expression or missing starting bracket", lineNumber: context.lineNumber, token: some(token)))
      return

    context.activeExpression.setLen(0)

    # result = nil
    echo ")"
    return currentNode

  of Show:
    discard

  of StartBlock:
    # backtracking
    if len(context.activeExpression) != 1:
      context.error.add(ParserError(message: "Invalid syntax: Block", lineNumber: context.lineNumber, token: some(token)))
      return

    context.activeExpression.add(token)

    let node = JamboneASTNode(kind: JamboneASTKind.jamBlock, blockName: "", contents: JamboneASTNode(kind: JamboneASTKind.jamRoot, children: @[]))
    #return match(match(node, tokens, context), tokens, context)
    return match(node, tokens, context)

  of EndBlock:
    let node = JamboneASTNode(kind: JamboneASTKind.jamEnd)
    return match(node, tokens, context)
    # set back to parent
    # let startblock =

  of IfBlock:
    discard

  of ElseBlock:
    discard

  of EndIfBlock:
    discard

proc parse*(currentNode: JamboneASTNode, tokens: var Deque[TokenOccurrence], context: var ParserContext, depth = 0): JamboneASTNode =
  if len(tokens) == 0:
    return currentNode

  if currentNode != nil:
    echo currentNode.kind

  var node = currentNode
  while len(tokens) > 0:
    let next = match(node, tokens, context)
    if next != nil:
      node = next
      if node.kind == JamboneASTKind.jamEnd:
        # Go back to parent
        return node

      currentNode.children.add(node)

      if node.kind == JamboneASTKind.jamBlock:
        # Parse the children
        let endNode = parse(node.contents, tokens, context, depth+1)
        if endNode.kind != JamboneASTKind.jamEnd:
          context.error.add(ParserError(message: "Block not ended!", lineNumber: context.lineNumber, token: none(TokenOccurrence)))

        currentNode.children.add(endNode)


  return currentNode

proc newParseTree*(source: string, tokens: var Deque[TokenOccurrence], view: Table[string, Showable]): JamboneAstNode =
  let root = JamboneASTNode(kind: JamboneASTKind.jamRoot, children: @[])
  var context = ParserContext(
    lineNumber: 0,
    # view: view,
    activeExpression: @[],
    error: @[]
  )

  # Create the root node
  let stream = newStringStream(source)

  result = parse(root, tokens, context)

  if len(context.error) > 0:
    echo "There were some errors"
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
