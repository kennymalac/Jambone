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

    var (startPos, startToken) = tokens[0]
    check startPos == 0
    check startToken == Token.StartExpression

    let (builtinPos, builtinToken) = tokens[1]
    check builtinPos == 3
    check builtinToken == Token.IfBlock

    var (endPos, endToken) = tokens[2]
    check endPos == 6
    check endToken == Token.EndExpression

    # cursor = newStringStream("{{ else }}")

  test "undefined identifier":
    #check error
    skip()
