# Spatial Object Drums — iPhone & Magic Keyboard

Apple Vision Pro가 **검은색 iPhone 17** 또는 **Apple Magic Keyboard**와 양손 검지를 추적하고, 손가락이 물체 위의 가상 타격면을 통과하면 공간 음향을 재생하는 visionOS 2+ 예제입니다. Swift-DocC 튜토리얼과 GitHub Pages 배포 워크플로도 같은 저장소에 포함합니다.

## 요구 사항

- macOS와 Xcode 16 이상
- visionOS 2 이상을 실행하는 Apple Vision Pro
- XcodeGen (`brew install xcodegen`)

Object Tracking은 Simulator에서 동작하지 않습니다. Simulator에서는 창과 일반 UI만 확인할 수 있고, 물체와 손가락 추적은 Vision Pro 실기기에서 시험해야 합니다.

## 바로 실행하기

저장소에는 학습과 무결성 검사를 마친 `iPhone17Black.referenceobject`와 세 가지 모노 타격음이 포함되어 있으므로 iPhone 테스트에는 다시 학습할 필요가 없습니다. Magic Keyboard를 사용하려면 아래 설치 명령을 먼저 실행합니다.

1. `make project`로 `SpatialObjectDrums.xcodeproj`를 생성합니다.
2. Xcode에서 프로젝트를 열고 앱 Target의 Signing Team을 선택합니다.
3. 자동 서명이 Bundle Identifier 충돌을 알리면 `com.example.SpatialObjectDrums`를 자신만의 값으로 변경합니다.
4. 페어링한 Apple Vision Pro를 실행 대상으로 선택하고 `⌘R`을 누릅니다.
5. 앱에서 **Start Drumming**을 누르고 손 추적과 주변 공간 접근을 허용합니다.

앱은 Immersive Space를 열기 전에 Reference Object를 검사합니다. 전환이 응답하지 않으면 12초 후 오류를 표시하므로, 다른 몰입형 앱을 종료하고 Vision Pro를 잠금 해제한 뒤 다시 시도하세요.

## Magic Keyboard Reference Object 설치

Apple의 공식 [Exploring object tracking with ARKit](https://developer.apple.com/documentation/visionos/exploring_object_tracking_with_arkit) 샘플에는 Apple Magic Keyboard용 Reference Object가 포함되어 있습니다. 다음 명령은 Apple이 공개한 visionOS 2용 샘플을 직접 다운로드하고 SHA-512와 Xcode 호환성을 확인한 뒤 프로젝트에 설치합니다.

```sh
make install-magic-keyboard
```

설치 결과는 다음 위치에 생성되며 Xcode 프로젝트도 자동으로 갱신됩니다.

```text
SpatialObjectDrums/Resources/ReferenceObjects/Apple_Magic_Keyboard.referenceobject
```

버전 호환성에 주의하세요.

| 개발 환경 | 사용할 Magic Keyboard 샘플 |
| --- | --- |
| Xcode 16~26, visionOS 2~26 | 이 저장소의 설치 스크립트가 받는 Apple 2024 샘플, Reference Object 포맷 1.0 |
| Xcode 27, visionOS 27 이상 | Apple 문서 페이지의 현재 Download, Reference Object 포맷 2.0 |

현재 Apple 문서의 최신 다운로드는 Xcode 27·visionOS 27용입니다. 이 파일을 Xcode 26 프로젝트에 바로 넣으면 `Unsupported version 2.0` 오류가 발생합니다. 설치 스크립트는 Apple이 계속 호스팅하는 Xcode 16·visionOS 2용 공식 아카이브를 사용합니다.

Apple 샘플 모델의 크기는 약 27.9 × 11.5cm인 컴팩트 Magic Keyboard 기준입니다. 숫자 키패드가 붙은 큰 모델은 외형과 크기가 다르므로 같은 모델로 안정적인 인식을 기대하기 어렵습니다. 다운로드 파일은 Apple 샘플에 포함된 라이선스의 적용을 받으며, 이 저장소는 해당 바이너리를 재배포하지 않고 Apple 서버에서 사용자가 직접 받도록 구성합니다.

## iPhone 놓는 방법

1. 케이스를 완전히 벗깁니다.
2. 부드러운 천이나 미끄럼 방지 매트 위에 화면이 아래로 가도록 놓습니다.
3. Vision Pro에서 카메라와 검은색 뒷면이 보이도록 밝은 조명을 사용합니다.
4. 카메라 렌즈를 피하고 뒷면 중앙이나 하단 위에서 손가락을 아래로 움직입니다.

인식되면 iPhone 위에 초록색 타격 영역과 `iPhone 17 Black 인식 완료` 안내가 나타납니다. 가상 타격면은 휴대폰 윗면보다 조금 높으므로 실제 기기를 세게 두드릴 필요가 없습니다.

## Reference Object와 소리

- 완성된 추적 모델: `SpatialObjectDrums/Resources/ReferenceObjects/iPhone17Black.referenceobject`
- 선택적 학습 소스: `TrainingAssets/iPhone17/iPhone17Black-LowPoly-v2.usdz`
- iPhone 음색: `SpatialObjectDrums/Resources/Audio/percussion-fx.wav`
- 선택 설치 모델: `SpatialObjectDrums/Resources/ReferenceObjects/Apple_Magic_Keyboard.referenceobject`
- Magic Keyboard 음색: `SpatialObjectDrums/Resources/Audio/wood-block.wav`

`DrumProfile.swift`는 공백, 밑줄, 하이픈을 제거한 이름에서 `iphone17`과 `magickeyboard`를 판별합니다. `SmallBox`와 `LabeledCan`용 기존 프로필도 확장 예제로 남아 있습니다.

## 선택적으로 다시 학습하기

자신의 iPhone을 촬영한 USDZ로 교체하고 싶을 때만 다음 명령을 사용합니다.

```sh
make train-iphone
```

학습 스크립트는 Create ML이 공백이 포함된 경로를 `%20` 폴더로 잘못 저장하는 문제를 피하기 위해 `/private/tmp`에서 학습한 뒤 결과를 올바른 프로젝트 폴더로 복사합니다. 결과 파일이 이미 존재하면 기존 모델을 보호하기 위해 학습을 건너뜁니다.

## 문서와 검증

```sh
make project
make validate
```

Xcode에서 **Product > Build Documentation**으로 로컬 튜토리얼을 확인할 수 있습니다. `main` 브랜치에 푸시하면 GitHub Actions가 DocC를 빌드해 GitHub Pages에 배포합니다.

- 튜토리얼: https://hmuzn.github.io/2026TechMap_tutorial/tutorials/spatialobjectdrums/
- `REFERENCEOBJECT_STRIP_USDZ=YES`가 적용되어 앱 번들에는 학습 원본 USDZ가 중복 포함되지 않습니다.

## 안전

휴대폰 카메라 렌즈나 키보드 키캡을 세게 두드리지 마세요. 주변 공간을 비우고, 추적 중에는 대상 물체를 움직이지 않는 편이 안정적입니다.
