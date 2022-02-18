import os
import Jambonepkg/jambone

when isMainModule:
  when declared(commandLineParams):
    let params = commandLineParams()
    echo runJambone(params[0])

  echo "Usage: jambone config.json"
