#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output="$project_root/SpatialObjectDrums/Resources/ReferenceObjects/Apple_Magic_Keyboard.referenceobject"









if [ -e "$output" ]; then
    echo "이미 설치됨: $output"
    exit 0
fi

for tool in curl unzip shasum awk; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "필요한 도구를 찾을 수 없습니다: $tool" >&2
        exit 1
    }
done


























if [ -n "${DEVELOPER_DIR:-}" ]; then
    developer_directory="$DEVELOPER_DIR"
elif [ -d /Applications/Xcode.app/Contents/Developer ]; then
    developer_directory=/Applications/Xcode.app/Contents/Developer
else
    developer_directory=$(xcode-select -p)
fi
compiler="$developer_directory/Toolchains/XcodeDefault.xctoolchain/usr/bin/referenceobjectc"
if [ ! -x "$compiler" ]; then
    echo "Xcode Reference Object 컴파일러를 찾지 못했습니다: $compiler" >&2
    exit 1
fi

xcodebuild="$developer_directory/usr/bin/xcodebuild"
xcode_major=$("$xcodebuild" -version | awk 'NR == 1 { split($2, version, "."); print version[1] }')
if [ -z "$xcode_major" ] || [ "$xcode_major" -lt 27 ]; then
    echo "이 Reference Object는 Xcode 27 이상이 필요합니다. 현재 Xcode: $("$xcodebuild" -version | head -n 1)" >&2
    exit 1
fi

"$compiler" "$extracted" "$compiled_directory" --strip-usdz
compiled="$compiled_directory/Apple_Magic_Keyboard.referenceobject"
test -s "$compiled" || {
    echo "Magic Keyboard Reference Object 호환성 검사에 실패했습니다." >&2
    exit 1
}

mkdir -p "$(dirname -- "$output")"
cp -p "$extracted" "$output"
echo "설치 완료: $output"
echo "출처: https://developer.apple.com/documentation/visionos/exploring_object_tracking_with_arkit"
echo "라이선스: $project_root/ThirdParty/Apple-ExploringObjectTracking-LICENSE.txt"

project_file="$project_root/SpatialObjectDrums.xcodeproj/project.pbxproj"
if [ -f "$project_file" ] && grep -F -q 'Apple_Magic_Keyboard.referenceobject' "$project_file"; then
    echo "커밋된 Xcode 프로젝트에 Magic Keyboard 리소스 참조가 이미 있습니다."
elif command -v xcodegen >/dev/null 2>&1; then
    "$project_root/Scripts/generate_project.sh"
    echo "Xcode 프로젝트에도 Magic Keyboard 모델을 반영했습니다."
else
    echo "XcodeGen이 없으므로 Xcode에서 위 파일을 앱 Target에 직접 추가하세요."
fi
