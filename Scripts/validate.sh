#!/bin/sh
set -eu

required="README.md project.yml SpatialObjectDrums/SpatialObjectDrumsApp.swift SpatialObjectDrums/ContentView.swift SpatialObjectDrums/DrumRealityView.swift SpatialObjectDrums/DrumAppModel.swift SpatialObjectDrums/TrackedDrum.swift SpatialObjectDrums/DrumProfile.swift SpatialObjectDrums/Info.plist SpatialObjectDrums/Resources/Audio/wood-block.wav SpatialObjectDrums/Resources/Audio/tom.wav SpatialObjectDrums/Resources/Audio/percussion-fx.wav SpatialObjectDrums/Resources/ReferenceObjects/iPhone17Black.referenceobject Scripts/generate_iphone17_usd.swift Scripts/install_magic_keyboard_referenceobject.sh Scripts/train_iphone17.sh TrainingAssets/iPhone17/iPhone17Black-LowPoly-v2.usdz SpatialObjectDrums.docc/SpatialObjectDrums.tutorial SpatialObjectDrums.docc/Resources/spatial-object-drums-hero.png SpatialObjectDrums.docc/Tutorials/01-Prepare.tutorial SpatialObjectDrums.docc/Tutorials/02-TrackObjects.tutorial SpatialObjectDrums.docc/Tutorials/03-PlayDrums.tutorial .github/workflows/deploy-docc.yml"
for file in $required; do
  test -e "$file" || { echo "missing: $file"; exit 1; }
done

grep -q 'DOCC_HOSTING_BASE_PATH: 2026TechMap_tutorial' project.yml
grep -q 'REFERENCEOBJECT_STRIP_USDZ: YES' project.yml
grep -q 'UIApplicationSupportsMultipleScenes: true' project.yml
grep -q 'iPhone 17 Black' SpatialObjectDrums/DrumProfile.swift
grep -q 'Apple Magic Keyboard' SpatialObjectDrums/DrumProfile.swift
grep -q 'SpatialObjectDrums-iPhone17Black' Scripts/train_iphone17.sh
grep -q '66b7ac751448/ExploringObjectTrackingWithARKit.zip' Scripts/install_magic_keyboard_referenceobject.sh
grep -q '66b7ac75144854b13c98c7cafe612aebe2779390085e9a1b19b3118b9c5707abb0e2419a7b9105e4ba142c8c2db73752cce999266f0b6ed4671ba875fa8b6586' Scripts/install_magic_keyboard_referenceobject.sh
grep -q 'DOCC_HOSTING_BASE_PATH=2026TechMap_tutorial' .github/workflows/deploy-docc.yml
grep -q '@Tutorials' SpatialObjectDrums.docc/SpatialObjectDrums.tutorial
grep -q 'NSHandsTrackingUsageDescription' SpatialObjectDrums/Info.plist
grep -q 'NSWorldSensingUsageDescription' SpatialObjectDrums/Info.plist
grep -q 'UIApplicationSupportsMultipleScenes' SpatialObjectDrums/Info.plist
plutil -lint SpatialObjectDrums/Info.plist >/dev/null

for audio in wood-block.wav tom.wav percussion-fx.wav; do
  test -s "SpatialObjectDrums/Resources/Audio/$audio" || { echo "empty audio: $audio"; exit 1; }
done

for source in ContentView.swift DrumAppModel.swift DrumProfile.swift DrumRealityView.swift TrackedDrum.swift Info.plist; do
  cmp -s "SpatialObjectDrums/$source" "SpatialObjectDrums.docc/Resources/$source" || {
    echo "DocC code sample is out of sync: $source"
    exit 1
  }
done

for tutorial in 01-Prepare 02-TrackObjects 03-PlayDrums; do
  grep -q "doc:$tutorial" SpatialObjectDrums.docc/SpatialObjectDrums.tutorial || {
    echo "missing tutorial reference: $tutorial"
    exit 1
  }
done

for resource in $(sed -n 's/.*file: "\([^"]*\)".*/\1/p' SpatialObjectDrums.docc/Tutorials/*.tutorial); do
  test -f "SpatialObjectDrums.docc/Resources/$resource" || { echo "missing DocC resource: $resource"; exit 1; }
done

if test -f SpatialObjectDrums.xcodeproj/project.pbxproj; then
  plutil -lint SpatialObjectDrums.xcodeproj/project.pbxproj >/dev/null
  grep -q 'iPhone17Black.referenceobject' SpatialObjectDrums.xcodeproj/project.pbxproj
  for audio in wood-block.wav tom.wav percussion-fx.wav; do
    grep -q "$audio" SpatialObjectDrums.xcodeproj/project.pbxproj || {
      echo "audio is not in the Xcode project: $audio"
      exit 1
    }
  done
  if test -f SpatialObjectDrums/Resources/ReferenceObjects/Apple_Magic_Keyboard.referenceobject; then
    grep -q 'Apple_Magic_Keyboard.referenceobject' SpatialObjectDrums.xcodeproj/project.pbxproj
  fi
fi

echo "Project, reference objects, audio, privacy settings, and DocC samples look valid."
