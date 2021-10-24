import unittest
import deques
import streams
import tables
import print

import Jambonepkg/jambone




suite "block parsing - phase 2":
  test "block":
    let source = "{{ block example }} ... {{ endblock }}"
    var tokens = tokenize(source)

    let root = newParseTree(source, tokens, { "test": "ok" }.toTable())

    check len(root.children) == 2
    check root.children[0].kind == JamboneAstKind.jamBlock
    check root.children[1].kind == JamboneAstKind.jamEnd
    check root.children[0].blockName == "example"
    print root

  test "nested blocks":
    let source = "{{ block example }} {{ block test }} {{ endblock }} {{ endblock }}"
    var tokens = tokenize(source)

    let root = newParseTree(source, tokens, { "test": "ok" }.toTable())

    check len(root.children) == 2

    check root.children[0].kind == JamboneAstKind.jamBlock
    check root.children[1].kind == JamboneAstKind.jamEnd
    check root.children[0].blockName == "example"

    check len(root.children[0].contents.children) == 2
    check root.children[0].contents.children[0].kind == JamboneAstKind.jamBlock
    check root.children[0].contents.children[1].kind == JamboneAstKind.jamEnd
    check root.children[0].contents.children[0].blockName == "test"

    print root


suite "if/else":
  test "if/elseif/else/endif":
    skip()

  #test ""
