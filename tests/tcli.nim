import tables
import unittest
import streams
import json

import Jambonepkg/jambone

suite "jambone cli":
  test "run with json config":
    let example = "<html><head><title>{{ $title }}</title></head></html>"
    check len(runJambone(%*{
      "layout": "tests/template.json",
      "pages": "tests/pages/",
      "assets": "tests/assets/",
      "output": "tests/dist/"
    })) == 2
