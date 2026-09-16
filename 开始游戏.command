#!/bin/zsh
set -e
PROJECT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
ENGINE="$PROJECT_DIR/.tools/Godot.app/Contents/MacOS/Godot"
if [[ ! -x "$ENGINE" ]]; then
  ENGINE="/Applications/Godot.app/Contents/MacOS/Godot"
fi
if [[ ! -x "$ENGINE" ]]; then
  print "请先安装 Godot 4，再导入此目录的 project.godot。"
  exit 1
fi
exec "$ENGINE" --path "$PROJECT_DIR"
