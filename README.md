# Spatial Object Drums — Magic Keyboard

Xcode 27과 visionOS 27에서 Apple Vision Pro의 Object Tracking과 Hand Tracking을 결합하는 Swift-DocC 튜토리얼입니다. Apple 공식 샘플과 대응하는 Magic Keyboard를 추적하고, 검지가 키보드 위의 가상 타격면을 통과하면 키보드의 Reference Object 원점에서 Wood Block 공간 음향을 재생합니다.

튜토리얼은 실행 코드뿐 아니라 USDZ 준비, Create ML Object Tracking 학습, `.referenceobject` 검증과 STEP별 전체 코드 하이라이트를 함께 다룹니다.

**웹 튜토리얼:** [https://hmuzn.github.io/2026TechMap_tutorial/tutorials/spatialobjectdrums/](https://hmuzn.github.io/2026TechMap_tutorial/tutorials/spatialobjectdrums/)

> **최근에 무엇이 바뀌었나요?** 2026년 10월 타격 안정성·양손 연주·설정 UI·자동 테스트 업데이트는 [`UPDATE_NOTES.md`](UPDATE_NOTES.md)에서 변경 전후 비교와 함께 확인할 수 있습니다.

## 요구 사항

- Xcode 27을 실행할 수 있는 Apple Silicon Mac
- Xcode 27과 visionOS 27 SDK
- visionOS 27 이상의 Apple Vision Pro
- XcodeGen (`brew install xcodegen`, 프로젝트를 다시 생성할 때만 필요)

Object Tracking과 Hand Tracking 실기기 결과는 Simulator에서 검증할 수 없습니다. Simulator는 창 UI와 일반 RealityKit 콘텐츠 확인에만 사용하세요.

## Magic Keyboard로 실행하기

Apple 최신 [Exploring object tracking with ARKit](https://developer.apple.com/documentation/visionos/exploring_object_tracking_with_arkit) 샘플에는 사전학습된 Magic Keyboard Reference Object가 포함되어 있습니다. 이 저장소는 Apple 바이너리를 재배포하지 않고 공식 샘플을 내려받아 저장소에 고정한 SHA-512와 Xcode 27 `referenceobjectc`로 검사합니다.

가장 간단한 방법은 아래 설치 명령을 사용하는 것입니다. 직접 설치하려면 Apple 샘플 페이지에서 **Download**를 누르거나 [공식 샘플 ZIP](https://docs-assets.developer.apple.com/published/d76adf975589/ExploringObjectTrackingWithARKit.zip)을 내려받고, 압축 안의 `Reference Objects/Apple_Magic_Keyboard.referenceobject`를 `SpatialObjectDrums/Resources/ReferenceObjects/Apple_Magic_Keyboard.referenceobject`로 복사한 뒤 `make project`를 실행합니다.

```sh
make install-magic-keyboard
make validate
```

저장소에 포함된 [`SpatialObjectDrums.xcodeproj`](SpatialObjectDrums.xcodeproj)를 열어 Signing Team과 페어링한 Apple Vision Pro를 선택하고 실행합니다. 앱에서 **Start Drumming**을 누른 뒤 World Sensing과 Hands Tracking 권한을 허용하세요. `project.yml`을 수정했다면 `make project`로 커밋된 프로젝트를 다시 생성합니다.

Apple 문서는 샘플 Reference Object가 대응하는 Magic Keyboard의 정확한 세대나 치수를 명시하지 않습니다. 공식 파일로 인식되지 않는 다른 외형의 키보드는 같은 모델이라고 가정하지 말고, 해당 실물의 USDZ로 별도 Reference Object를 학습해야 합니다.

## 자신의 Reference Object 학습하기

USDZ 준비와 Create ML 학습이 처음부터 부담스럽다면 이 과정은 건너뛰고 위의 Apple 공식 Magic Keyboard Reference Object로 앱 실행부터 확인하세요. 공식 파일이 자신의 키보드를 인식하지 않거나 다른 실물을 추적할 때만 자체 학습이 필요합니다.

학습 전에 다음 항목을 먼저 확인합니다.

1. USDZ가 실제 물체의 형상, 재질과 표면 특징을 충분히 재현하는가
2. 모델의 절대 치수가 실물과 일치하는가
3. +Y 위쪽과 front 방향이 실제 사용 자세와 일치하는가
4. 필요한 viewing angle만 선택했는가
5. 비슷한 물체를 Objects to Avoid에 추가해야 하는가

정지된 탁상 물체는 `standard`와 `upright`를 우선 출발점으로 사용합니다. 물체가 모든 방향으로 회전하지 않는다면 불필요한 viewing angle을 제외하고, 비슷한 물체와 혼동된다면 Create ML의 **Objects to Avoid**에 그 물체의 USDZ를 추가합니다.

```sh
./Scripts/train_reference_object.sh \
  --source /path/to/MyObject.usdz \
  --output SpatialObjectDrums/Resources/ReferenceObjects/MyObject.referenceobject \
  --mode standard \
  --viewing-angle upright
```

`extended`는 더 많은 학습 데이터와 큰 모델을 사용해 가장 높은 추적 품질을 목표로 하지만, 학습 시간과 프레임당 실행 비용도 커집니다. 특히 손에 들고 움직이는 물체를 visionOS 27의 high-frame-rate tracking으로 추적할 때 우선 검토하고, 정지 물체에서는 실제 테스트 결과가 Standard보다 나을 때 선택합니다.

학습 스크립트는 결과를 임시 폴더에 만든 뒤 Xcode 27 `referenceobjectc` 검증에 성공한 경우에만 지정한 출력 경로에 복사합니다. 기존 결과를 덮어쓸 때는 `--force`를 명시해야 합니다.

비슷한 물체 하나를 negative example로 함께 학습하려면 위 명령에 `--avoid /path/to/SimilarObject.usdz`를 추가합니다. 여러 negative example이나 반복 학습 프로젝트를 관리할 때는 Create ML 앱의 **Objects to Avoid**와 프로젝트 저장 기능을 사용하세요.

## 구현 구조

- `DrumAppModel.swift`: Reference Object 로드, ARKitSession, Object/Hand Anchor update
- `TrackedDrum.swift`: Magic Keyboard 바운딩 박스, 가상 타격면, 공간 음향과 opacity 피드백
- `HitDetector.swift`: 프레임 시간, 이동 거리와 하강 속도를 반영하는 순수 타격 판정
- `DrumTuning.swift`: 타격면 높이, 최소 속도, 연타 간격과 표시 설정
- `DrumProfile.swift`: Reference Object 이름과 Wood Block 음원 연결
- `DrumRealityView.swift`: RealityView 생명주기와 상태 오버레이
- `SpatialObjectDrums.docc`: 준비, Object Tracking, 손 타격의 세 튜토리얼

## DocC 작성과 검증

### Xcode에서 보기

처음 클론한 저장소라면 `make install-magic-keyboard`를 먼저 실행합니다. 그다음 Xcode 27로 [`SpatialObjectDrums.xcodeproj`](SpatialObjectDrums.xcodeproj)를 열고 **Product > Build Documentation**을 선택합니다. Developer Documentation 창이 열리면 **Spatial Object Drums > Tutorials**에서 세 장을 순서대로 볼 수 있습니다.

브라우저에서 빠르게 미리 보려면 저장소 루트에서 다음 명령을 실행하고 터미널에 표시되는 로컬 주소를 엽니다.

```sh
make preview-docc
```

기본 `8080` 포트를 다른 프로그램이 사용 중이면 `DOCC_PREVIEW_PORT=8081 make preview-docc`처럼 포트를 바꿀 수 있습니다.

### 웹에서 바로 보기

`main` 브랜치의 앱과 DocC 빌드가 성공하면 GitHub Pages에 자동 배포됩니다.

- 공개 URL: [https://hmuzn.github.io/2026TechMap_tutorial/tutorials/spatialobjectdrums/](https://hmuzn.github.io/2026TechMap_tutorial/tutorials/spatialobjectdrums/)
- 기능 브랜치와 Pull Request: 빌드 검증만 수행
- `main` 브랜치: 검증 후 공개 사이트 갱신

### GitHub Actions 결과 내려받기

각 브랜치의 **Validate visionOS 27 App and DocC** 실행은 렌더링된 `SpatialObjectDrums-DocC` 아티팩트를 30일 동안 보관합니다. 저장소의 **Actions > 해당 실행 > Artifacts**에서 내려받고, 안에 있는 `SpatialObjectDrums.doccarchive.zip`까지 압축을 풀어 `SpatialObjectDrums.doccarchive`를 Xcode 27로 열 수 있습니다.

```sh
make sync-docc-code
make validate
```

각 기술 STEP은 실제 앱의 완성 파일 전체를 보여주고, `previousFile` 비교를 이용해 그 STEP에서 설명하는 부분만 강조합니다. `make sync-docc-code`는 앱 소스 복사본과 강조 비교 파일을 함께 갱신합니다.

DocC의 기본 데스크톱 렌더러는 빠른 스크롤로 활성선을 건너뛰면 이전 STEP을 유지할 수 있고, STEP이 바뀌어도 긴 코드 파일의 첫 강조 행까지 코드 패널을 자동으로 이동하지 않습니다. `make preview-docc`로 여는 브라우저 미리보기와 공개 Pages 아티팩트는 화면 높이 35% 지점에 가장 가까운 STEP을 스크롤할 때마다 다시 계산하고, 활성 STEP의 강조 구간이 코드 패널 안에 보이도록 최소한으로 이동합니다. 오른쪽 코드 패널 위에서 세로로 스크롤해도 페이지의 다음·이전 STEP으로 진행하며, 전체 코드를 따로 살펴볼 때는 코드 패널의 스크롤 막대를 직접 드래그할 수 있습니다. 모바일 레이아웃은 DocC가 기본 제공하는 강조 구간 미리보기를 그대로 사용합니다. Xcode의 Developer Documentation 창은 내장 렌더러를 사용하므로 이 웹 전용 스크롤 보정 없이 STEP별 강조만 표시합니다.

텍스트만 있던 STEP의 오른쪽 미디어 패널에는 장비 준비, Reference Object 설치·학습, 추적 복구, 손가락 타격과 세션 생명주기를 설명하는 이미지를 배치했습니다. 대부분은 절차와 공간 관계를 설명하기 위한 **개념 이미지**입니다. Create ML 시작 화면과 `Spatial > Object Tracking` 템플릿 선택 화면은 Create ML 6.2의 실제 캡처이며, 메뉴 이름과 버튼 위치는 사용하는 Xcode 27 빌드에서 다시 확인하세요. 권한 대화상자와 실기기 추적 결과도 Apple Vision Pro에서 최종 확인해야 합니다.

Xcode에서 **Product > Build Documentation**을 선택해 최종 렌더링을 확인하세요. Pull Request에서는 빌드만 검증하고, 공개 Pages 배포는 `main`의 검증이 성공했을 때만 실행합니다.

## 안정성 검증

타격 판정은 ARKit과 분리된 `HitDetector`로 구현해 정상 하향 통과, 역방향 이동, 영역 밖 통과, 느린 움직임, 오래되거나 비정상적으로 큰 좌표 변화를 단위 테스트합니다. 앱의 **연주 감도 설정**에서 타격면 높이, 최소 타격 속도, 양손별 연타 간격과 타격면 표시 여부를 실물·사용자에 맞게 조절할 수 있습니다.

실기기 검증은 [`TESTING.md`](TESTING.md)의 체크리스트와 측정표를 사용합니다. Xcode·visionOS 빌드, 키보드 모델, 조도, 첫 인식 시간, 100회 타격 누락·오인식, 양손 연타와 추적 복구 결과를 함께 기록하세요.

## Apple 샘플 라이선스

Magic Keyboard Reference Object는 Apple 공식 샘플에서 사용자가 직접 내려받으며 [Apple 샘플 라이선스](ThirdParty/Apple-ExploringObjectTracking-LICENSE.txt)가 적용됩니다. 해당 바이너리는 `.gitignore`로 커밋 대상에서 제외합니다.

## 출처와 프로젝트 라이선스

이 저장소의 기존 Spatial Object Drums 튜토리얼을 visionOS 27, Xcode 27과 Magic Keyboard 실습에 맞게 다시 구성했습니다.

이 저장소에는 프로젝트 전체에 적용되는 별도의 오픈 소스 라이선스가 아직 선언되어 있지 않습니다. 공개 열람은 코드, 문서, 이미지 또는 오디오의 재사용 허가를 의미하지 않습니다. Apple이 제공하는 샘플과 Reference Object에는 위의 별도 Apple 라이선스가 적용됩니다.
