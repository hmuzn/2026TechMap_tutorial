# Reference Object 리소스

공식 Magic Keyboard 예제를 설치하려면 저장소 루트에서 다음 명령을 실행하세요.

```sh
make install-magic-keyboard
```

설치 스크립트는 Apple 샘플의 `Apple_Magic_Keyboard.referenceobject`를 이 폴더에 복사하고 Xcode 27의 `referenceobjectc`로 검증합니다. 이 바이너리는 Apple 샘플 라이선스에 따라 Git에는 포함하지 않습니다.

직접 만든 USDZ를 학습하려면 `make train-reference-object` 또는 `Scripts/train_reference_object.sh`를 사용하세요. 완성 파일은 이 폴더에 넣고 Target Membership을 켭니다. 실제 물체와 USDZ의 크기·좌표축을 맞추고, 책상 위에서만 사용할 물체는 `upright`, 여러 방향에서 볼 물체는 `all` viewing angle을 선택하세요.
