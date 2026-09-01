#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
reference_object="$project_root/SpatialObjectDrums/Resources/ReferenceObjects/Apple_Magic_Keyboard.referenceobject"
created_placeholder=0

cleanup() {
    if [ "$created_placeholder" -eq 1 ]; then
        rm -f "$reference_object"
    fi
}
trap cleanup 0 1 2 15

command -v xcodegen >/dev/null 2>&1 || {
    echo "XcodeGen이 필요합니다. brew install xcodegen을 먼저 실행하세요." >&2
    exit 1
}

# Apple의 Reference Object 바이너리는 저장소에 재배포하지 않습니다.
# 파일이 아직 설치되지 않았어도 생성된 프로젝트가 항상 같은 리소스
# 참조를 갖도록, XcodeGen을 실행하는 동안에만 빈 자리표시자를 만듭니다.
if [ ! -e "$reference_object" ]; then
    mkdir -p "$(dirname -- "$reference_object")"
    touch "$reference_object"
    created_placeholder=1
fi

cd "$project_root"
xcodegen generate
