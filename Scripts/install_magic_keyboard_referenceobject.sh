#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output="$project_root/SpatialObjectDrums/Resources/ReferenceObjects/Apple_Magic_Keyboard.referenceobject"

# Apple published this sample for Xcode 16 and visionOS 2. The current Apple
# download uses Reference Object format 2.0 and requires Xcode/visionOS 27, so
# this installer intentionally uses Apple's still-hosted 2024 sample archive.
archive_url="https://docs-assets.developer.apple.com/published/66b7ac751448/ExploringObjectTrackingWithARKit.zip"
archive_sha512="66b7ac75144854b13c98c7cafe612aebe2779390085e9a1b19b3118b9c5707abb0e2419a7b9105e4ba142c8c2db73752cce999266f0b6ed4671ba875fa8b6586"
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

echo "Apple 공식 visionOS 2 Object Tracking 샘플을 다운로드합니다."
curl -L --fail --silent --show-error "$archive_url" -o "$archive"

actual_sha512=$(shasum -a 512 "$archive" | awk '{print $1}')
if [ "$actual_sha512" != "$archive_sha512" ]; then
    echo "다운로드 파일의 SHA-512가 Apple 공개 체크섬과 다릅니다." >&2
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

if command -v xcodegen >/dev/null 2>&1; then
    (cd "$project_root" && xcodegen generate)
    echo "Xcode 프로젝트에도 Magic Keyboard 모델을 반영했습니다."
else
    echo "XcodeGen이 없으므로 Xcode에서 위 파일을 앱 Target에 직접 추가하세요."
fi
