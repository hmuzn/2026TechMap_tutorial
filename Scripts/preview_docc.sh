#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
preview_port=${DOCC_PREVIEW_PORT:-8080}

case "$preview_port" in
    ''|*[!0-9]*)
        echo "DOCC_PREVIEW_PORT에는 1부터 65535 사이의 숫자를 지정하세요." >&2
        exit 1
        ;;
esac
if [ "$preview_port" -lt 1 ] || [ "$preview_port" -gt 65535 ]; then
    echo "DOCC_PREVIEW_PORT에는 1부터 65535 사이의 숫자를 지정하세요." >&2
    exit 1
fi

if [ -n "${DEVELOPER_DIR:-}" ]; then
    developer_directory=$DEVELOPER_DIR
elif [ -d /Applications/Xcode.app/Contents/Developer ]; then
    developer_directory=/Applications/Xcode.app/Contents/Developer
else
    developer_directory=$(xcode-select -p 2>/dev/null || true)
fi

if [ -z "$developer_directory" ]; then
    echo "전체 Xcode를 찾지 못했습니다. Xcode 27을 설치하거나 DEVELOPER_DIR를 지정하세요." >&2
    exit 1
fi

docc=$(DEVELOPER_DIR="$developer_directory" /usr/bin/xcrun --find docc 2>/dev/null || true)
if [ -z "$docc" ] || [ ! -x "$docc" ]; then
    echo "선택한 Xcode에서 DocC를 찾지 못했습니다: $developer_directory" >&2
    exit 1
fi

cd "$project_root"
preview_archive="$project_root/SpatialObjectDrums.docc/.docc-build"
highlight_injector="$project_root/Scripts/inject_docc_step_highlight_scroll.py"
step_sync_patcher="$project_root/Scripts/patch_docc_tutorial_step_sync.py"
last_step_sync_error=""
last_highlight_error=""
preview_pid=""

cleanup() {
    if [ -n "$preview_pid" ] && kill -0 "$preview_pid" 2>/dev/null; then
        kill -INT "$preview_pid" 2>/dev/null || true
        wait "$preview_pid" 2>/dev/null || true
    fi
    preview_pid=""
}

trap cleanup 0 1 2 15

set -m
env DEVELOPER_DIR="$developer_directory" /usr/bin/xcrun docc preview SpatialObjectDrums.docc \
    --port "$preview_port" \
    --fallback-display-name SpatialObjectDrums \
    --fallback-bundle-identifier com.example.SpatialObjectDrums \
    --fallback-bundle-version 1.0 &
preview_pid=$!
set +m

while kill -0 "$preview_pid" 2>/dev/null; do
    if [ -f "$preview_archive/index.html" ]; then
        if step_sync_output=$("$step_sync_patcher" "$preview_archive" 2>&1); then
            last_step_sync_error=""
        elif [ "$step_sync_output" != "$last_step_sync_error" ]; then
            echo "DocC STEP 동기화 적용 실패(자동 재시도): $step_sync_output" >&2
            last_step_sync_error=$step_sync_output
        fi

        if highlight_output=$("$highlight_injector" "$preview_archive" 2>&1); then
            last_highlight_error=""
        elif [ "$highlight_output" != "$last_highlight_error" ]; then
            echo "DocC 강조 이동 적용 실패(자동 재시도): $highlight_output" >&2
            last_highlight_error=$highlight_output
        fi
    fi
    sleep 1
done

preview_status=0
wait "$preview_pid" || preview_status=$?
preview_pid=""
trap - 0 1 2 15
exit "$preview_status"
