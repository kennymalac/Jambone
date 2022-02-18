import unittest
import streams

import Jambonepkg/jambone

suite "block parsing - phase 1":
  test "builtin tokens":
    # TODO make this a function and test every token
    var cursor = newStringStream("{{ if }}")
    var tokens = newSeq[TokenOccurrence]()
    for tokenOccurrence in tokenizer(cursor):
      tokens.add(tokenOccurrence)

    echo tokens

    var (startPos, startToken) = tokens[0]
    check startPos == 0
    check startToken.kind == TokenKind.jamKeyword
    check startToken.keyword == KeywordTokenKind.StartExpression

    let (builtinPos, builtinToken) = tokens[1]
    check builtinPos == 3
    check builtinToken.kind == TokenKind.jamKeyword
    check builtinToken.keyword == KeywordTokenKind.IfBlock

    var (endPos, endToken) = tokens[2]
    check endPos == 6
    check endToken.kind == TokenKind.jamKeyword
    check endToken.keyword == KeywordTokenKind.EndExpression

    # cursor = newStringStream("{{ else }}")

  test "undefined identifier":
    #check error
    skip()
