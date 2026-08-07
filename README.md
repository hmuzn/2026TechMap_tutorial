# Spatial Object Drums

Apple Vision Pro에서 미리 학습한 실물 물체를 추적하고, 손가락으로 물체의 윗면을 두드리면 크기와 형태에 맞는 공간 음향을 재생하는 visionOS 2+ 예제입니다. 동일한 저장소에 Swift-DocC 튜토리얼과 GitHub Pages 배포 워크플로를 포함합니다.

## 요구 사항

- macOS와 Xcode 16 이상
- visionOS 2 이상을 실행하는 Apple Vision Pro (Simulator는 Object Tracking을 지원하지 않음)
- XcodeGen (`brew install xcodegen`)
- Create ML로 만든 실제 물체별 `.referenceobject` 파일

## 시작하기

1. `make project`로 `SpatialObjectDrums.xcodeproj`를 생성합니다.
2. Xcode에서 프로젝트를 열고 Signing Team을 선택합니다.
3. Target의 **Signing & Capabilities**에서 **World Sensing**을 추가합니다.
4. `SpatialObjectDrums/Resources/ReferenceObjects`의 안내 파일을 자신의 `.referenceobject` 파일로 교체합니다.
5. Apple Vision Pro에서 실행합니다.

샘플은 `SmallBox`, `LabeledCan`, `AsymmetricContainer`라는 참조 이름을 음색 프로필과 연결합니다. 다른 이름을 쓴다면 `DrumProfile.swift`도 함께 수정하세요.

## 문서와 배포

Xcode에서 **Product > Build Documentation**으로 로컬 문서를 확인할 수 있습니다. `main` 브랜치에 푸시하면 `.github/workflows/deploy-docc.yml`이 DocC archive를 만들어 GitHub Pages에 배포합니다. 저장소 이름과 hosting base path는 공지에 맞춰 `2026TechMap_tutorial`로 고정했습니다.

## 리소스에 관하여

`Scripts/generate_audio.swift`는 저작권 문제 없는 짧은 합성 타격음 세 개를 만드는 보조 스크립트입니다. 전체 Xcode가 선택된 환경에서 `swift Scripts/generate_audio.swift SpatialObjectDrums/Resources/Audio`로 실행하거나, 직접 제작·사용 허가를 받은 모노 WAV를 같은 이름으로 넣으세요. `.referenceobject`는 특정 실물의 형상·크기·질감에 종속되므로 저장소에서 범용 파일을 제공할 수 없습니다.

## 안전

깨지거나 날카롭거나 쉽게 움직이는 물체를 사용하지 마세요. 주변 공간을 비우고, 물체에는 미끄럼 방지 패드를 부착하세요.
