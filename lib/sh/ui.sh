#!/usr/bin/env bash
# ============================================================
# Clack-style terminal UI (bash 3.2+)
#
# Usage: . "$ROOT/lib/sh/ui.sh"
#
#   ui_intro "title"                      ┌  title
#   ui_step "message"                     ◇  message
#   ui_info / ui_warn / ui_error "msg"    ● / ▲ / ■  msg
#   ui_line "text"                        │  text
#   ui_note "title" "line" "line"...      boxed note
#   ui_multiselect "q" "label|hint|on"... -> UI_RESULT=(indices)
#   ui_select "q" "label|hint" ...        -> UI_ANSWER=index
#   ui_confirm "q" [y|n]                  -> return 0 (yes) / 1 (no)
#   ui_text "q" [default]                 -> UI_ANSWER=string
#   ui_spin "msg" logfile cmd args...     -> spinner while cmd runs
#   ui_outro "message"                    └  message
# ============================================================

_UI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/ui" && pwd)"

. "$_UI_DIR/core.sh"
. "$_UI_DIR/prompt.sh"
. "$_UI_DIR/spinner.sh"
