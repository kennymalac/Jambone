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


suite "layout block tests":
  test "import from file":
    let example = "<html> {{ block test }} t {{ endblock }} 1</html>"
    check render(example, %*{ "blocks": [{ "name": "test", "provider": "tests/example-block.html" }] }) == "<html> unicorn\n 1</html>"

  test "derive in child":
    let parentExample = "<html>{{ block test }} t {{ endblock }}</html>"
    let parentConfig = %*{ "blocks": [{ "name": "test", "provider": nil }]}
    let childExample = "{{ block test }}123{{ endblock }}"
    check render(parentExample, parentConfig) == "<html> t </html>"
    check renderTemplate(childExample, parentExample, parentConfig) == "<html>123</html>"

  test "nesting parent block":
    skip()
