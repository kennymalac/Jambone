import tables
import unittest
import streams
import json

import Jambonepkg/jambone

suite "variables":
  test "echoing string":
    let example = "<html><head><title>{{ $title }}</title></head></html>"
    check render(example, { "title": "Example" }.toTable()) == "<html><head><title>Example</title></head></html>"

suite "conditional rendering":
  test "if statement":
    let example = "<html>{{ if condition }}no??{{ endif }}</html>"
    check render(example, { "condition": true }.toTable()) == "<html>no??</html>"
    check render(example, { "condition": false }.toTable()) == "<html></html>"

  test "else statement":
    let example = "<html>{{ if condition }}no??{{ else }}well how come??{{ endif }}</html>"
    check render(example, { "condition": true }.toTable()) == "<html>no??</html>"
    check render(example, { "condition": false }.toTable()) == "<html>well how come??</html>"

  test "elseif statement":
    let example = "<html>{{ if condition }}no??{{ elseif otherCondition }}oh??{{ endif }}</html>"
    check render(example, { "condition": true, "otherCondition": true }.toTable()) == "<html>no??</html>"
    check render(example, { "condition": true, "otherCondition": false }.toTable()) == "<html>no??</html>"
    check render(example, { "condition": false, "otherCondition": true }.toTable()) == "<html>oh??</html>"
    check render(example, { "condition": false, "otherCondition": false }.toTable()) == "<html></html>"

  test "multiple elseif statements":
    # TODO
    skip()

  test "if/elseif/else statements":
    let example = "<html>{{ if condition }}no??{{ elseif otherCondition }}oh??{{ else }}well how come??{{ endif }}</html>"
    check render(example, { "condition": true, "otherCondition": true }.toTable()) == "<html>no??</html>"
    check render(example, { "condition": true, "otherCondition": false }.toTable()) == "<html>no??</html>"
    check render(example, { "condition": false, "otherCondition": true }.toTable()) == "<html>oh??</html>"
    check render(example, { "condition": false, "otherCondition": false }.toTable()) == "<html>well how come??</html>"

  test "missing variable":
    let example = "<html>{{ if condition }}no??{{ elseif otherCondition }}oh??{{ else }}well how come??{{ endif }}</html>"
    # TODO check that this fails
    check render(example, { "condition": true }.toTable()) == "ERROR: otherCondition is not defined"

  test "early endif":
    let example = "<html>{{ if condition }}no??{{ elseif otherCondition }}oh??{{ endif}}{{ else }}well how come??{{ endif }}</html>"
    check render(example, { "condition": true, "otherCondition": true }.toTable()) == "ERROR: missing if statement for keyword 'else'"

  test "missing endif":
    let example = "<html>{{ if condition }}no??{{ elseif otherCondition }}oh??{{ else }}well how come??</html>"
    check render(example, { "condition": true, "otherCondition": true }.toTable()) == "ERROR: missing endif block"


suite "nested blocks":
  test "one level":
    skip()
  test "two levels":
    skip()

suite "layout tests":
  setup:
    let parent = "<html><head><title>{{ block title }}Default text{{ endblock }}</title></head></html>"
    let config = %* {
      "templates": {
        "parent": parent # TODO test filename
      }
    }
  test "extending a template":
    let child = "{{ extend \"parent\" }}"
    check render(child, { "test": "ok" }.toTable(), config) == "<html><head><title>Default text</title></head></html>"

  test "overriding a block":
    let child = "{{ extend \"parent\" }} {{ block title }}New title{{ endblock }}"
    check render(child, { "test": "ok" }.toTable(), config) == "<html><head><title>New title</title></head></html>"

  test "nesting parent block":
    skip()
