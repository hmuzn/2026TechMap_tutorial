#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output="$project_root/SpatialObjectDrums/Resources/ReferenceObjects/Apple_Magic_Keyboard.referenceobject"

# This is the current Xcode 27 / visionOS 27 sample linked from Apple's
# "Exploring object tracking with ARKit" documentation. The checksum is pinned
# by this repository so an upstream archive change fails closed and can be
# reviewed before the binary is installed.
archive_url="https://docs-assets.developer.apple.com/published/d76adf975589/ExploringObjectTrackingWithARKit.zip"
archive_sha512="d76adf97558952e1debb3171549b81b405c692fbb4e9c8397b62f191d14d01575ec0d466a18e85af1cf9cd255c16f4fc1f8a2afa445d4fe21f85482eacd71cf2"
archive_member="Reference Objects/Apple_Magic_Keyboard.referenceobject"

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

temporary_directory=$(mktemp -d /private/tmp/SpatialObjectDrums-MagicKeyboard.XXXXXX)
trap 'rm -rf "$temporary_directory"' 0 1 2 15
archive="$temporary_directory/ExploringObjectTrackingWithARKit.zip"
extracted_directory="$temporary_directory/extracted"
compiled_directory="$temporary_directory/compiled"
mkdir -p "$extracted_directory" "$compiled_directory"

echo "Apple 공식 Xcode 27 / visionOS 27 Object Tracking 샘플을 다운로드합니다."
curl -L --fail --silent --show-error "$archive_url" -o "$archive"

actual_sha512=$(shasum -a 512 "$archive" | awk '{print $1}')
if [ "$actual_sha512" != "$archive_sha512" ]; then
    echo "다운로드 파일의 SHA-512가 저장소에 고정된 값과 다릅니다." >&2
    echo "expected: $archive_sha512" >&2
    echo "actual:   $actual_sha512" >&2
    exit 1
fi

unzip -j -q "$archive" "$archive_member" -d "$extracted_directory"
extracted="$extracted_directory/Apple_Magic_Keyboard.referenceobject"
test -s "$extracted" || {
    echo "Apple 샘플에서 Magic Keyboard Reference Object를 찾지 못했습니다." >&2
    exit 1
}

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
