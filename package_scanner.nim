
# A very simple Nim package scanner.
#
# Scans the package list from this repository.
#
# Check the packages for:
#  * Missing name
#  * Missing/unknown method
#  * Missing/unreachable repository
#  * Missing tags
#  * Missing description
#  * Missing/unknown license
#  * Insecure git:// url on GitHub
#
# Usage: nim c -d:ssl -r package_scanner.nim
#
# Copyright 2015 Federico Ceratto <federico.ceratto@gmail.com>
# Released under GPLv3 License, see /usr/share/common-licenses/GPL-3

import httpclient
import net
import json
import os
import sets
import strutils

const
  LICENSES = @[
    "Allegro 4 Giftware",
    "Apache License 2.0",
    "BSD",
    "BSD2",
    "BSD3",
    "CC0",
    "GPL",
    "GPLv2",
    "GPLv3",
    "LGPLv2",
    "LGPLv3",
    "MIT",
    "MS-PL",
    "MPL",
    "WTFPL",
    "libpng",
    "zlib",
    "ISC",
    "Unlicense"
  ]

  VCS_TYPES = @["git", "hg"]

  CATEGORIES = @[
    "*Dead*",
    "Algorithms",
    "Cloud",
    "Database",
    "Data science",
    "Development",
    "Education",
    "FFI",
    "Finance",
    "Games",
    "GUI",
    "Hardware",
    "JS",
    "Language",
    "Maths",
    "Miscelaneous",
    "Network",
    "Reporting",
    "Science",
    "Tools",
    "Video, image and audio",
    "Web"
  ]

proc canFetchNimbleRepository(name: string, urlJson: JsonNode): bool =
  # The fetch is a lie!
  # TODO: Make this check the actual repo url and check if there is a
  #       nimble file in it
  result = true
  var url: string

  if not urlJson.isNil:
    url = urlJson.str

    try:
      var client = newHttpClient(userAgent="Nim/Package Scanner", timeout=10000)
      discard getContent(client, url)
    except HttpRequestError, TimeoutError:
      echo "W: ", name, ": unable to fetch repo ", url, " ",
           getCurrentExceptionMsg()
    except AssertionError:
      echo "W: ", name, ": httpclient failed ", url, " ",
           getCurrentExceptionMsg()
    except:
      echo "W: Another error attempting to request: ", url
      echo "  Error was: ", getCurrentExceptionMsg()

proc verifyAlias(pdata: JsonNode, result: var int) =
  if not pdata.hasKey("name"):
    echo "E: missing alias' package name"
    result.inc()

  # TODO: Verify that 'alias' points to a known package.

proc check(): int =
  var name: string
  echo ""
  let pkg_list = parseJson(readFile(getCurrentDir() / "packages.json"))
  var names = initHashSet[string]()

  for pdata in pkg_list:
    name = if pdata.hasKey("name"): pdata["name"].str else: ""

    if pdata.hasKey("alias"):
      verifyAlias(pdata, result)
    else:
      if name == "":
        echo "E: missing package name"
        result.inc()
      elif not pdata.hasKey("method"):
        echo "E: ", name, " has no method"
        result.inc()
      elif not (pdata["method"].str in VCS_TYPES):
        echo "E: ", name, " has an unknown method: ", pdata["method"].str
        result.inc()
      elif not pdata.hasKey("url"):
        echo "E: ", name, " has no URL"
        result.inc()
      elif pdata.hasKey("web") and not canFetchNimbleRepository(name, pdata["web"]):
        result.inc()
      elif not pdata.hasKey("tags"):
        echo "E: ", name, " has no tags"
        result.inc()
      elif not pdata.hasKey("description"):
        echo "E: ", name, " has no description"
        result.inc()
      elif not pdata.hasKey("license"):
        echo "E: ", name, " has no license"
        result.inc()
      elif pdata["url"].str.normalize.startsWith("git://github.com/"):
        echo "E: ", name, " has an insecure git:// URL instead of https://"
        result.inc()
      elif pdata.hasKey("code-quality"):
        if not (pdata["code-quality"].kind == JInt and
            pdata["code-quality"].num in 0 .. 4):
          echo "E: ", name, " code-quality must be in range [1..4]"
          result.inc()
      elif pdata.hasKey("doc-quality"):
        if not (pdata["doc-quality"].kind == JInt and
            pdata["doc-quality"].num in 0 .. 4):
          echo "E: ", name, " doc-quality must be in range [1..4]"
          result.inc()
      elif pdata.hasKey("project-quality"):
        if not (pdata["project-quality"].kind == JInt and
            pdata["project-quality"].num in 0 .. 4):
          echo "E: ", name, " project-quality must be in range [1..4]"
          result.inc()
      else:
        # Other warnings should go here
        if not (pdata["license"].str in LICENSES):
          echo "W: ", name, " has an unexpected license: ", pdata["license"]
        elif not (pdata["categories"].str in CATEGORIES):
          echo "W: ", name, " has an unexpected category: ", pdata["categories"]
        elif not pdata.hasKey("extended-description"):
          echo "W: ", name, " has no detailed description"

    if name.normalize notin names:
      names.incl(name.normalize)
    else:
      echo("E: ", name, ": a package by that name already exists.")
      result.inc()

  echo ""
  echo "Problematic packages count: ", result


when isMainModule:
  quit(check())

