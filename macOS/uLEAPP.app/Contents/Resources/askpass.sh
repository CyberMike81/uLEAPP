#!/bin/sh
# sudo consumes this helper's stdout directly. The updater never logs it.
exec "$(dirname "$0")/../MacOS/uLEAPP" --askpass
