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

## 안전

깨지거나 날카롭거나 쉽게 움직이는 물체를 사용하지 마세요. 주변 공간을 비우고, 물체에는 미끄럼 방지 패드를 부착하세요.
