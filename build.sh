#!/bin/sh
# TouchEn 켜기·끄기 앱을 빌드합니다.
# 사용법: ./build.sh [출력 폴더]   (기본: 저장소의 build/)
set -eu

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
OUT_DIR=${1:-"$REPO_DIR/build"}
APP="$OUT_DIR/TouchEn 켜기·끄기.app"

mkdir -p "$OUT_DIR"
rm -rf "$APP"
osacompile -o "$APP" "$REPO_DIR/src/touchen-toggle.applescript"
echo "빌드 완료: $APP"
