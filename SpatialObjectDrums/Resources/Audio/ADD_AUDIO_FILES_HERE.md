# 오디오 리소스

기본 Magic Keyboard 예제는 짧은 모노 WAV 파일 두 개를 사용합니다.

- `wood-block.wav`: Magic Keyboard를 두드렸을 때의 기본 음색
- `percussion-fx.wav`: 직접 학습한 다른 Reference Object의 대체 음색

전체 Xcode가 선택된 Mac에서는 저장소 루트에서 다음 명령으로 합성 샘플을 다시 만들 수 있습니다.

```sh
swift Scripts/generate_audio.swift SpatialObjectDrums/Resources/Audio
```

직접 녹음한 파일로 교체할 때는 파일 이름과 Target Membership을 그대로 유지하세요.
