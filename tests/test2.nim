import unittest
import deques
import streams
import tables

import Jambonepkg/jambone




suite "block parsing - phase 2":
  test "startblock":
    let source = "{{ block example }}"
    var tokens = tokenize(source)

    let root = newParseTree(source, tokens, { "test": "ok" }.toTable())
    echo "root kind:"
    echo root.kind

    check len(root.children) == 1
    echo $root.children[0]

  test "endblock":
    let source = "{{ block example }} ... {{ endblock }}"
    var tokens = tokenize(source)

    let root = newParseTree(source, tokens, { "test": "ok" }.toTable())

    check len(root.children) == 1
    echo $root.children[0]

  test "nested blocks":
    let source = "{{ block example }} {{ block test }} {{ endblock }} {{ endblock }}"
    var tokens = tokenize(source)

    let root = newParseTree(source, tokens, { "test": "ok" }.toTable())

    check len(root.children) == 1
    echo $root.children[0]

    check len(root.children[0].contents.children) == 2
    check root.children[0].kind == JamboneAstKind.jamBlock
    echo $root.children[0].contents.children[0]
    check root.children[0].contents.children[1].kind == JamboneAstKind.jamEnd
    echo $root.children[0].contents.children[1]


suite "if/else":
  test "if/elseif/else/endif":
    skip()

  #test ""
