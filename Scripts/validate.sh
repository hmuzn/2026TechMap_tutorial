#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"

fail() {
    echo "검증 실패: $*" >&2
    exit 1
}

require_file() {
    [ -e "$1" ] || fail "필수 파일이 없습니다: $1"
}

require_text() {
    pattern=$1
    file=$2
    grep -F -q -- "$pattern" "$file" || fail "$file 에 필요한 설정이 없습니다: $pattern"
}

required_files="
README.md
Makefile
project.yml
Scripts/generate_docc_highlights.py
Scripts/docc-step-highlight-scroll.js
Scripts/generate_project.sh
Scripts/inject_docc_step_highlight_scroll.py
Scripts/patch_docc_tutorial_step_sync.py
Scripts/install_magic_keyboard_referenceobject.sh
Scripts/preview_docc.sh
Scripts/train_reference_object.sh
ThirdParty/Apple-ExploringObjectTracking-LICENSE.txt
SpatialObjectDrums/SpatialObjectDrumsApp.swift
SpatialObjectDrums/ContentView.swift
SpatialObjectDrums/DrumRealityView.swift
SpatialObjectDrums/DrumAppModel.swift
SpatialObjectDrums/TrackedDrum.swift
SpatialObjectDrums/DrumProfile.swift
SpatialObjectDrums/Info.plist
SpatialObjectDrums/Resources/Audio/wood-block.wav
SpatialObjectDrums/Resources/Audio/percussion-fx.wav
SpatialObjectDrums.docc/SpatialObjectDrums.tutorial
SpatialObjectDrums.docc/Resources/spatial-object-drums-hero-v2.png
SpatialObjectDrums.docc/Resources/reference-object-training-pipeline.svg
SpatialObjectDrums.docc/Resources/reference-object-training-pipeline.png
SpatialObjectDrums.docc/Tutorials/01-Prepare.tutorial
SpatialObjectDrums.docc/Tutorials/02-TrackObjects.tutorial
SpatialObjectDrums.docc/Tutorials/03-PlayDrums.tutorial
SpatialObjectDrums.xcodeproj/project.pbxproj
SpatialObjectDrums.xcodeproj/project.xcworkspace/contents.xcworkspacedata
SpatialObjectDrums.xcodeproj/xcshareddata/xcschemes/SpatialObjectDrums.xcscheme
.github/workflows/deploy-docc-pages.yml
.github/workflows/validate-docc.yml
"

for file in $required_files; do
    require_file "$file"
done

require_text 'visionOS: "27.0"' project.yml
require_text 'SWIFT_VERSION: "6.0"' project.yml
require_text 'DOCC_HOSTING_BASE_PATH: 2026TechMap_tutorial' project.yml
require_text 'REFERENCEOBJECT_STRIP_USDZ: YES' project.yml
require_text 'UIApplicationSupportsMultipleScenes: true' project.yml
require_text 'ReferenceObject.Configuration()' SpatialObjectDrums/DrumAppModel.swift
require_text 'highFrameRateTrackingEnabled = false' SpatialObjectDrums/DrumAppModel.swift
require_text 'Apple Magic Keyboard' SpatialObjectDrums/DrumProfile.swift
require_text 'wood-block.wav' SpatialObjectDrums/DrumProfile.swift
require_text 'd76adf975589/ExploringObjectTrackingWithARKit.zip' Scripts/install_magic_keyboard_referenceobject.sh
require_text 'd76adf97558952e1debb3171549b81b405c692fbb4e9c8397b62f191d14d01575ec0d466a18e85af1cf9cd255c16f4fc1f8a2afa445d4fe21f85482eacd71cf2' Scripts/install_magic_keyboard_referenceobject.sh
require_text '--training-mode "$training_mode"' Scripts/train_reference_object.sh
require_text 'runs-on: xcode-27' .github/workflows/validate-docc.yml
require_text 'DOCC_HOSTING_BASE_PATH=2026TechMap_tutorial' .github/workflows/validate-docc.yml
require_text '--expected-base-url /2026TechMap_tutorial/' .github/workflows/validate-docc.yml
require_text 'Validate visionOS 27 App and DocC' .github/workflows/deploy-docc-pages.yml
require_text 'actions/upload-pages-artifact@v5' .github/workflows/deploy-docc-pages.yml
require_text 'actions/deploy-pages@v5' .github/workflows/deploy-docc-pages.yml
require_text '@Tutorials' SpatialObjectDrums.docc/SpatialObjectDrums.tutorial
require_text 'NSHandsTrackingUsageDescription' SpatialObjectDrums/Info.plist
require_text 'NSWorldSensingUsageDescription' SpatialObjectDrums/Info.plist
require_text 'UIApplicationSupportsMultipleScenes' SpatialObjectDrums/Info.plist

plutil -lint SpatialObjectDrums/Info.plist >/dev/null || fail "Info.plist 형식이 올바르지 않습니다."
sh -n Scripts/install_magic_keyboard_referenceobject.sh || fail "Magic Keyboard 설치 스크립트 구문 오류"
sh -n Scripts/generate_project.sh || fail "Xcode 프로젝트 생성 스크립트 구문 오류"
sh -n Scripts/train_reference_object.sh || fail "Reference Object 학습 스크립트 구문 오류"
sh -n Scripts/preview_docc.sh || fail "DocC 미리보기 스크립트 구문 오류"
python3 -m py_compile Scripts/generate_docc_highlights.py || fail "DocC 코드 동기화 스크립트 구문 오류"
python3 -m py_compile Scripts/inject_docc_step_highlight_scroll.py || fail "DocC 강조 이동 주입 스크립트 구문 오류"
python3 -m py_compile Scripts/patch_docc_tutorial_step_sync.py || fail "DocC STEP 동기화 패치 스크립트 구문 오류"
if command -v node >/dev/null 2>&1; then
    node --check Scripts/docc-step-highlight-scroll.js || fail "DocC 강조 이동 JavaScript 구문 오류"
fi
./Scripts/generate_docc_highlights.py --check || fail "DocC 완성 코드 또는 STEP 강조 파일이 실제 소스와 다릅니다. make sync-docc-code를 실행하세요."

require_text 'inject_docc_step_highlight_scroll.py' .github/workflows/validate-docc.yml
require_text 'patch_docc_tutorial_step_sync.py' .github/workflows/validate-docc.yml
require_text '--check' .github/workflows/validate-docc.yml
require_text 'preview.scrollTo({' Scripts/docc-step-highlight-scroll.js
require_text 'forwardCodePanelWheel' Scripts/docc-step-highlight-scroll.js
require_text 'activationRatio = 0.35' Scripts/docc-step-highlight-scroll.js

for audio in wood-block.wav percussion-fx.wav; do
    [ -s "SpatialObjectDrums/Resources/Audio/$audio" ] || fail "오디오 파일이 비어 있습니다: $audio"
done

for tutorial in 01-Prepare 02-TrackObjects 03-PlayDrums; do
    require_text "doc:$tutorial" SpatialObjectDrums.docc/SpatialObjectDrums.tutorial
done

code_count=$(grep -h '@Code(' SpatialObjectDrums.docc/Tutorials/*.tutorial | wc -l | tr -d ' ')
[ "$code_count" -eq 24 ] || fail "DocC STEP 코드 예제 수가 예상과 다릅니다: $code_count (예상 24)"

final_code_resources=$(sed -n 's/.*@Code(name: "[^"]*", file: "\([^"]*\)", previousFile:.*/\1/p' SpatialObjectDrums.docc/Tutorials/*.tutorial)
previous_code_resources=$(sed -n 's/.*previousFile: "\([^"]*\)".*/\1/p' SpatialObjectDrums.docc/Tutorials/*.tutorial)
final_code_count=$(printf '%s\n' "$final_code_resources" | sed '/^$/d' | wc -l | tr -d ' ')
unique_final_code_count=$(printf '%s\n' "$final_code_resources" | sed '/^$/d' | sort -u | wc -l | tr -d ' ')
previous_code_count=$(printf '%s\n' "$previous_code_resources" | sed '/^$/d' | wc -l | tr -d ' ')
unique_previous_code_count=$(printf '%s\n' "$previous_code_resources" | sed '/^$/d' | sort -u | wc -l | tr -d ' ')
[ "$final_code_count" -eq "$code_count" ] || fail "@Code final file 참조를 모두 읽지 못했습니다: $final_code_count/$code_count"
[ "$unique_final_code_count" -eq "$code_count" ] || fail "각 STEP은 고유한 final code snapshot을 사용해야 합니다: $unique_final_code_count/$code_count"
[ "$previous_code_count" -eq "$code_count" ] || fail "@Code previousFile 참조를 모두 읽지 못했습니다: $previous_code_count/$code_count"
[ "$unique_previous_code_count" -eq "$code_count" ] || fail "각 STEP은 고유한 previousFile을 사용해야 합니다: $unique_previous_code_count/$code_count"

for resource in $final_code_resources; do
    require_file "SpatialObjectDrums.docc/Resources/$resource"
done
for resource in $previous_code_resources; do
    require_file "SpatialObjectDrums.docc/Resources/$resource"
    [ -s "SpatialObjectDrums.docc/Resources/$resource" ] || fail "STEP 강조 비교 파일이 비어 있습니다: $resource"
done

image_resources=$(sed -n 's/.*@Image(source: "\([^"]*\)".*/\1/p' SpatialObjectDrums.docc/*.tutorial SpatialObjectDrums.docc/Tutorials/*.tutorial)
image_count=$(printf '%s\n' "$image_resources" | sed '/^$/d' | wc -l | tr -d ' ')
[ "$image_count" -eq 50 ] || fail "DocC 설명 이미지 수가 예상과 다릅니다: $image_count (예상 50)"
for resource in $image_resources; do
    require_file "SpatialObjectDrums.docc/Resources/$resource"
done

if grep -R -n -E '컴팩트 Magic Keyboard|iPhone 17|Xcode 16|visionOS 2\.0|SmallBox|LabeledCan|AsymmetricContainer|tom\.wav' README.md SpatialObjectDrums SpatialObjectDrums.docc/Tutorials SpatialObjectDrums.docc/SpatialObjectDrums.tutorial; then
    fail "Magic Keyboard 단일 경로에 구버전 또는 iPhone 17 설명이 남아 있습니다."
fi

plutil -lint SpatialObjectDrums.xcodeproj/project.pbxproj >/dev/null || fail "생성된 Xcode 프로젝트 형식이 올바르지 않습니다."
require_text 'wood-block.wav' SpatialObjectDrums.xcodeproj/project.pbxproj
require_text 'percussion-fx.wav' SpatialObjectDrums.xcodeproj/project.pbxproj
require_text 'Apple_Magic_Keyboard.referenceobject' SpatialObjectDrums.xcodeproj/project.pbxproj
for reference_object in SpatialObjectDrums/Resources/ReferenceObjects/*.referenceobject; do
    [ -f "$reference_object" ] || continue
    require_text "$(basename -- "$reference_object")" SpatialObjectDrums.xcodeproj/project.pbxproj
done

developer_directory=""
if [ -n "${DEVELOPER_DIR:-}" ]; then
    developer_directory=$DEVELOPER_DIR
elif [ -d /Applications/Xcode.app/Contents/Developer ]; then
    developer_directory=/Applications/Xcode.app/Contents/Developer
elif command -v xcode-select >/dev/null 2>&1; then
    developer_directory=$(xcode-select -p 2>/dev/null || true)
fi

xcode_major=""
if [ -n "$developer_directory" ] && [ -x "$developer_directory/usr/bin/xcodebuild" ]; then
    xcode_major=$($developer_directory/usr/bin/xcodebuild -version | awk 'NR == 1 { split($2, version, "."); print version[1] }')
fi

validation_directory=$(mktemp -d /private/tmp/SpatialObjectDrums-Validation.XXXXXX)
trap 'rm -rf "$validation_directory"' 0 1 2 15

if [ -n "$developer_directory" ]; then
    docc=$(
        DEVELOPER_DIR="$developer_directory" /usr/bin/xcrun --find docc 2>/dev/null || true
    )
    if [ -n "$docc" ] && [ -x "$docc" ]; then
        "$docc" convert SpatialObjectDrums.docc \
            --fallback-display-name SpatialObjectDrums \
            --fallback-bundle-identifier com.example.SpatialObjectDrums \
            --fallback-bundle-version 1.0 \
            --output-path "$validation_directory/DocCArchive" \
            --warnings-as-errors
        ./Scripts/patch_docc_tutorial_step_sync.py "$validation_directory/DocCArchive" >/dev/null
        ./Scripts/patch_docc_tutorial_step_sync.py "$validation_directory/DocCArchive" --check >/dev/null
        ./Scripts/inject_docc_step_highlight_scroll.py "$validation_directory/DocCArchive" >/dev/null
        ./Scripts/inject_docc_step_highlight_scroll.py "$validation_directory/DocCArchive" --check >/dev/null
    fi
fi

if [ -z "$xcode_major" ] || [ "$xcode_major" -lt 27 ]; then
    if [ "${REQUIRE_XCODE_27:-0}" = 1 ]; then
        fail "Xcode 27 이상을 선택해야 합니다."
    fi
    echo "주의: 이 Mac에서는 Xcode 27을 찾지 못해 앱 빌드와 Reference Object 컴파일 검사를 건너뜁니다." >&2
else
    magic_keyboard=SpatialObjectDrums/Resources/ReferenceObjects/Apple_Magic_Keyboard.referenceobject
    if [ "${REQUIRE_REFERENCE_OBJECT:-0}" = 1 ] && [ ! -s "$magic_keyboard" ]; then
        fail "Magic Keyboard Reference Object가 없습니다. make install-magic-keyboard를 실행하세요."
    fi

    reference_object_count=0
    compiler="$developer_directory/Toolchains/XcodeDefault.xctoolchain/usr/bin/referenceobjectc"
    [ -x "$compiler" ] || fail "Xcode 27 Reference Object Compiler를 찾지 못했습니다: $compiler"
    for reference_object in SpatialObjectDrums/Resources/ReferenceObjects/*.referenceobject; do
        [ -f "$reference_object" ] || continue
        reference_object_count=$((reference_object_count + 1))
        reference_name=$(basename -- "$reference_object")
        reference_output="$validation_directory/ReferenceObject/$reference_object_count"
        mkdir -p "$reference_output"
        "$compiler" "$reference_object" "$reference_output" --strip-usdz >/dev/null
        [ -s "$reference_output/$reference_name" ] || fail "referenceobjectc가 검증 결과를 만들지 못했습니다: $reference_name"
    done

    if [ "$reference_object_count" -eq 0 ]; then
        if [ "${REQUIRE_REFERENCE_OBJECT:-0}" = 1 ]; then
            fail "Magic Keyboard Reference Object가 없습니다. make install-magic-keyboard를 실행하세요."
        fi
        echo "주의: Reference Object가 없어 바이너리 호환성 검사를 건너뜁니다." >&2
    fi
fi

git diff --check || fail "공백 또는 패치 형식 오류가 있습니다."

echo "검증 완료: visionOS 27 설정, Magic Keyboard 코드, Reference Object 학습 문서, 24개 STEP 강조 자료가 일치합니다."
