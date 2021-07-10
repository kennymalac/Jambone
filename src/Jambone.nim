# This is just an example to get you started. A typical hybrid package
# uses this file as the main entry point of the application.
import strutils
import tables
import Jambonepkg/jambone

let test = dedent """{{ $variable }}
shit
{{ block test }}

{{ endblock }}

{{ if variable }}
<b>blah</b>
{{ else }}
<b>not blah</b>
{{ endif }}

sentnkarsoinehtrasoietnarsientksrtienototeisrnatieonatta
en
{{ block }}

{{{ block }} // ERROR
{{ endblock }}
"""


when isMainModule:
  echo render(test, initTable[string, string]())
  
