#!/bin/sh
set -eu





























while [ "$#" -gt 0 ]; do
    case "$1" in
        --source)
            [ "$#" -ge 2 ] || { echo "--source 값이 필요합니다." >&2; exit 2; }
            source_model=$2
            shift 2
            ;;
        --output)
            [ "$#" -ge 2 ] || { echo "--output 값이 필요합니다." >&2; exit 2; }
            output=$2
            shift 2
            ;;
        --mode)
            [ "$#" -ge 2 ] || { echo "--mode 값이 필요합니다." >&2; exit 2; }
            training_mode=$2
            shift 2
            ;;
        --viewing-angle)
            [ "$#" -ge 2 ] || { echo "--viewing-angle 값이 필요합니다." >&2; exit 2; }
            viewing_angle=$2
            shift 2
            ;;
        --avoid)
            [ "$#" -ge 2 ] || { echo "--avoid 값이 필요합니다." >&2; exit 2; }
            avoid_model=$2
            shift 2
            ;;
        --force)
            force=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "알 수 없는 옵션: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[ -n "$source_model" ] || { echo "--source가 필요합니다." >&2; usage >&2; exit 2; }
[ -n "$output" ] || { echo "--output이 필요합니다." >&2; usage >&2; exit 2; }
[ -f "$source_model" ] || { echo "USDZ를 찾을 수 없습니다: $source_model" >&2; exit 1; }

case "$source_model" in
    *.usdz) ;;
    *) echo "--source는 .usdz 파일이어야 합니다: $source_model" >&2; exit 2 ;;
esac

case "$output" in
    *.referenceobject) ;;
    *) echo "--output은 .referenceobject 경로여야 합니다: $output" >&2; exit 2 ;;
esac

if [ -n "$avoid_model" ] && [ ! -f "$avoid_model" ]; then
    echo "피해야 할 물체의 USDZ를 찾을 수 없습니다: $avoid_model" >&2
    exit 1
fi

case "$training_mode" in
    standard|extended) ;;
    *) echo "--mode는 standard 또는 extended여야 합니다." >&2; exit 2 ;;
esac

case "$viewing_angle" in
    upright) viewing_flag="--upright" ;;
    all) viewing_flag="--all-angles" ;;
    front) viewing_flag="--front" ;;
    *) echo "--viewing-angle은 upright, all, front 중 하나여야 합니다." >&2; exit 2 ;;
esac

if [ -e "$output" ] && [ "$force" -ne 1 ]; then
    echo "출력 파일이 이미 있습니다: $output" >&2
    echo "검증된 기존 모델을 덮어쓰려면 --force를 명시하세요." >&2
    exit 1
fi

if [ -n "${DEVELOPER_DIR:-}" ]; then
    developer_directory=$DEVELOPER_DIR
elif [ -d /Applications/Xcode.app/Contents/Developer ]; then
    developer_directory=/Applications/Xcode.app/Contents/Developer
else
    developer_directory=$(xcode-select -p)
fi

compiler="$developer_directory/Toolchains/XcodeDefault.xctoolchain/usr/bin/referenceobjectc"
[ -x "$compiler" ] || {
    echo "Xcode Reference Object 컴파일러를 찾지 못했습니다: $compiler" >&2
    exit 1
}

xcodebuild="$developer_directory/usr/bin/xcodebuild"
xcode_major=$("$xcodebuild" -version | awk 'NR == 1 { split($2, version, "."); print version[1] }')
if [ -z "$xcode_major" ] || [ "$xcode_major" -lt 27 ]; then
    echo "visionOS 27용 Reference Object 학습에는 Xcode 27 이상이 필요합니다." >&2
    echo "현재 Xcode: $("$xcodebuild" -version | head -n 1)" >&2
    exit 1
fi

temporary_directory=$(mktemp -d /private/tmp/SpatialObjectDrums-Training.XXXXXX)
trap 'rm -rf "$temporary_directory"' 0 1 2 15
trained="$temporary_directory/Trained.referenceobject"
compiled_directory="$temporary_directory/compiled"
mkdir -p "$compiled_directory"
