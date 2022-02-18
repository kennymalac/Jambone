import json
import tables
import sequtils
import deques
import strutils
import strformat
import streams
import options
import os

import print

##################
### UTILITY
##################
iterator reverse*[T](a: seq[T]): T {.inline.} =
  var i = len(a) - 1
  while i > -1:
    yield a[i]
    dec(i)

##################
### CONFIGURATION
##################
type
  Showable* = concept x
    $(x) is string

type
  BlockConfig* = object of RootObj
    name: string
    provider: Option[string]

  JamboneConfig* = object of RootObj
    fileName*: Option[string]
    blocks*: seq[BlockConfig]

  JamboneSiteConfig* = object of RootObj
    layout: string
    pages: string
    assets: string
    output: string

################
### PARSER
################
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
    startPos*: int
    endPos*: int
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
    if c == ' ' or c == '\0' or c == '}':
      # TODO literals
      # if c == '\'' or c == '"':
      # string literal
      # if c.isDigit
      # number literal
      # TODO comments
      if isValidKeyword(tokenStr):
        # Don't skip this last character
        region.setPosition(region.getPosition()-1)
        return (pos: tokenPos, token: some(newKeyword(tokenStr)))

      elif validIdentifier(tokenStr):
        # Don't skip this last character
        region.setPosition(region.getPosition()-1)
        return (pos: tokenPos, token: some(Token(kind: TokenKind.jamIdentifier, identifier: tokenStr)))

      else:
        if c == '\0':
          break
        elif c == '}':
          tokenStr.add(c)
          if isValidKeyword(tokenStr):
            region.setPosition(region.getPosition())
            return (pos: tokenPos, token: some(newKeyword(tokenStr)))

        else:
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

  if token.token.kind == TokenKind.jamIdentifier:
    if len(context.activeExpression) == 0:
      #context.warning.add(ParserWarning
      echo "Parser warning: Lone identifier token outside of expression, tokenizer fucked up, something could go wrong.\n"

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
    if len(context.activeExpression) < 1 or currentNode == nil:
      context.error.add(ParserError(message: "Empty expression or missing starting bracket", lineNumber: context.lineNumber, token: some(token)))
      return

    # Set position of expression in the source string
    currentNode.startPos = context.activeExpression[0].pos
    currentNode.endPos = token.pos + len($(KeywordTokenKind.EndExpression))

    context.activeExpression.setLen(0)

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
    #TODO
    let node = JamboneASTNode(kind: JamboneASTKind.jamIf, condition: JamboneASTNode(kind: JamboneASTKind.jamRoot, children: @[]), ifContents: JamboneASTNode(kind: JamboneASTKind.jamRoot, children: @[]), elseContents: JamboneASTNode(kind: JamboneASTKind.jamRoot, children: @[]))
    return node

  of ElseBlock:
    return currentNode

  of EndIfBlock:
    return currentNode

proc parse*(currentNode: JamboneASTNode, tokens: var Deque[TokenOccurrence], context: var ParserContext, depth = 0): JamboneASTNode =
  if len(tokens) == 0:
    return currentNode

  var node = currentNode
  while len(tokens) > 0:
    let next = match(node, tokens, context)
    if next != nil:
      node = next
      if node.kind == JamboneASTKind.jamEnd and depth > 0:
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

################
### EVALUATION
################
type EvalResult = object
  contents: string
  blocks: Table[string,string]

proc evalJambone*(ast: JamboneASTNode, source: string, blocks: Table[string,string]): EvalResult =
  var cursor = newStringStream(source)

  assert ast.kind == JamboneASTKind.jamRoot
  assert len(ast.children) > 0

  # keep track of block descendants
  # so we can add parsed block results to the blocks table
  var resultBlocks = initTable[string,string]()

  # initiate stack with root node as start
  var evalStack = @[ast]
  var evalResultStack = @[(name: "_root", contents: "")]
  var evalResult = evalResultStack.pop()

  while len(evalStack) != 0:
    let expr = evalStack.pop()

    case expr.kind:
      of jamRoot:
        for child in reverse(expr.children):
          evalStack.add(child)

      of jamBlock:
        # Add contents prior to new block to current block
        evalResult.contents.add(cursor.readStr(expr.startPos-cursor.getPosition()))
        cursor.setPosition(expr.endPos)
        # Put current block back into the output stack and replace with new block below
        evalResultStack.add(evalResult)

        if expr.blockName in blocks:
          # Use provided block string to replace whatsever inside this block, ignore children
          evalResult = (name: expr.blockName, contents: blocks[expr.blockName])
        else:
          evalResult = (name: expr.blockName, contents: "")
          # Descend into block contents to replace current eval
          evalStack.add(expr.contents)

      of jamEnd:
        # Don't add what's inside block if it was provided
        if not(evalResult.name in blocks):
          evalResult.contents.add(cursor.readStr(expr.startPos-cursor.getPosition()))
        let name = evalResult.name
        resultBlocks[name] = evalResult.contents
        evalResult = evalResultStack.pop()
        # add child block contents to parent
        evalResult.contents.add(resultBlocks[name])
        cursor.setPosition(expr.endPos)

      else:
        # skip
        evalResult.contents.add(cursor.readStr(expr.startPos-cursor.getPosition()))
        cursor.setPosition(expr.endPos)

  # add all remaining text
  var line = ""
  while cursor.readLine(line):

    evalResult.contents.add(line)

  result = EvalResult(contents: evalResult.contents, blocks: resultBlocks)

let defaultConfig = %*{ "blocks": [] }
var defaultView = initTable[string, string]()

#proc getBlocks*(ast: JamboneAstNode): Table[string, string] =

proc getBlocks*(config: JamboneConfig): Table[string, string] =
  result = initTable[string, string]()
  for bConfig in config.blocks:
    if bConfig.provider.isSome and bConfig.provider.get().len > 0:
      result[bConfig.name] = readFile(bConfig.provider.get())


proc render*(source: string, config: JamboneConfig): string =
  var tokens = tokenize(source)
  var ast = newParseTree(source, tokens, { "test": "ok" }.toTable())

  let evalResult = evalJambone(ast, source, getBlocks(config))
  return evalResult.contents

proc render*(source: string, view: Table[string, Showable]): string =
  #TODO views.
  let jamConfig = defaultConfig.to(JamboneConfig)
  return render(source, jamConfig)

proc render*(source: string, config: JsonNode = defaultConfig): string =
  let jamConfig = config.to(JamboneConfig)
  return render(source, jamConfig)

proc renderTemplate*(childSource: string, layoutSource: string, layoutConfig: JamboneConfig): string =
  var childTokens = tokenize(childSource)
  var childAst = newParseTree(childSource, childTokens, { "test": "ok" }.toTable())
  # TODO separate child blocks config
  let child = evalJambone(childAst, childSource, getBlocks(layoutConfig))

  var tokens = tokenize(layoutSource)
  var ast = newParseTree(layoutSource, tokens, { "test": "ok" }.toTable())
  var blocks = getBlocks(layoutConfig)

  for name, blockContents in child.blocks:
    blocks[name] = blockContents

  let evalResult = evalJambone(ast, layoutSource, blocks)

  return evalResult.contents

proc renderTemplate*(source: string, layoutSource: string, layoutConfig: JsonNode): string =
  let jamConfig = layoutConfig.to(JamboneConfig)
  return renderTemplate(source, layoutSource, jamConfig)

proc runJambone*(config: JsonNode): seq[tuple[output: string, templateName: string]] =
  result = result
  let siteConfig = config.to(JamboneSiteConfig)
  let layoutConfig = parseFile(siteConfig.layout).to(JamboneConfig)
  let layoutFileName = layoutConfig.fileName.get()
  let layoutSource = readFile(layoutFileName)
  let pages = toSeq(walkDir(siteConfig.pages))
  let assets = toSeq(walkDir(siteConfig.assets))

  for page in pages:
    let output = renderTemplate(readFile(page.path), layoutSource, layoutConfig)
    result.add((output: output, templateName: layoutFileName))
    var outFileName = page.path.replace(siteConfig.pages, siteConfig.output).replace(".jam.html", ".html")

    let outFile = open(outFileName, fmWrite)
    outFile.write(output)
    outFile.close()

  for asset in assets:
    copyFile(asset.path, asset.path.replace(siteConfig.assets, siteConfig.output))

proc runJambone*(config: string): seq[tuple[output: string, templateName: string]] =
  return runJambone(parseFile(config))
