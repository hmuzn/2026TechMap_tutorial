#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_model="$project_root/TrainingAssets/iPhone17/iPhone17Black-LowPoly-v2.usdz"
checkpoint="$project_root/TrainingAssets/iPhone17/CreateMLCheckpoint"
output="$project_root/SpatialObjectDrums/Resources/ReferenceObjects/iPhone17Black.referenceobject"
# The Create ML CLI percent-encodes spaces in an output path on some Xcode
# versions (for example, "Spatial Computing" becomes a different
# "Spatial%20Computing" directory). Train to a no-space temporary path and
# copy the verified result into the project afterwards.
training_output="/private/tmp/SpatialObjectDrums-iPhone17Black-$$.referenceobject"
developer_dir=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

if [ -e "$output" ]; then
    echo "이미 생성됨: $output"
    exit 0
fi

if [ ! -f "$source_model" ]; then
    echo "학습 모델을 찾을 수 없습니다: $source_model" >&2
    exit 1
fi

mkdir -p "$checkpoint"

echo "iPhone 17 Black 추적 모델 학습을 시작합니다."
echo "Mac에 따라 몇 시간이 걸릴 수 있습니다. 전원을 연결하고 가능하면 완료될 때까지 중단하지 마세요."
echo "Create ML이 체크포인트를 기록한 이후에는 같은 명령으로 이어갈 수 있지만, 초기 중단은 처음부터 다시 시작될 수 있습니다."

DEVELOPER_DIR="$developer_dir" xcrun createml objecttracker \
    --upright \
    --checkpoint "$checkpoint" \
    --summary \
    --csv-progress \
    --source "$source_model" \
    --output "$training_output"

if [ ! -e "$training_output" ]; then
    echo "Create ML이 종료됐지만 결과 파일이 생성되지 않았습니다: $training_output" >&2
    echo "체크포인트는 보존되어 있으므로 같은 명령으로 다시 이어갈 수 있습니다." >&2
    exit 1
fi

mkdir -p "$(dirname -- "$output")"
cp -p "$training_output" "$output"

echo "완료: $output"

if command -v xcodegen >/dev/null 2>&1; then
    echo "새 Reference Object를 Xcode 프로젝트에 반영합니다."
    (cd "$project_root" && xcodegen generate)
    echo "Xcode 프로젝트 갱신 완료. 이제 Team을 선택하고 Vision Pro에서 빌드하세요."
else
    echo "xcodegen을 찾지 못했습니다. Xcode에서 생성된 파일을 앱 Target에 직접 추가하세요:"
    echo "$output"
fi
