#!/usr/bin/env python3
"""Synchronize DocC code and generate per-step final/baseline snapshot pairs."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "SpatialObjectDrums.docc" / "Resources"
TUTORIALS = ROOT / "SpatialObjectDrums.docc" / "Tutorials"


RESOURCE_SOURCES = {
    "Makefile": ROOT / "Makefile",
    "project.yml": ROOT / "project.yml",
    "install_magic_keyboard_referenceobject.sh": ROOT / "Scripts" / "install_magic_keyboard_referenceobject.sh",
    "train_reference_object.sh": ROOT / "Scripts" / "train_reference_object.sh",
    "Info.plist": ROOT / "SpatialObjectDrums" / "Info.plist",
    "SpatialObjectDrumsApp.swift": ROOT / "SpatialObjectDrums" / "SpatialObjectDrumsApp.swift",
    "ContentView.swift": ROOT / "SpatialObjectDrums" / "ContentView.swift",
    "DrumAppModel.swift": ROOT / "SpatialObjectDrums" / "DrumAppModel.swift",
    "DrumProfile.swift": ROOT / "SpatialObjectDrums" / "DrumProfile.swift",
    "DrumRealityView.swift": ROOT / "SpatialObjectDrums" / "DrumRealityView.swift",
    "TrackedDrum.swift": ROOT / "SpatialObjectDrums" / "TrackedDrum.swift",
}


@dataclass(frozen=True)
class Span:
    start: str | None = None
    end: str | None = None
    include_end: bool = True
    through_end: bool = False
    start_occurrence: int | None = None


@dataclass(frozen=True)
class Highlight:
    resource: str
    spans: tuple[Span, ...]


@dataclass(frozen=True)
class CodeReference:
    tutorial: str
    line: int
    name: str
    file: str
    previous_file: str


HIGHLIGHTS = {
    # Tutorial 01 — environment, assets, and project structure.
    "H-T01-01-Makefile-before": Highlight(
        "Makefile",
        (
            Span("project:", "\t./Scripts/generate_project.sh"),
            Span("preview-docc:", "\t./Scripts/preview_docc.sh"),
            Span("validate:", "\t./Scripts/validate.sh"),
        ),
    ),
    "H-T01-02-project-before.yml": Highlight(
        "project.yml",
        (
            Span("  deploymentTarget:", "targets:", include_end=False),
            Span("targets:", "    info:", include_end=False),
            Span("        REFERENCEOBJECT_STRIP_USDZ: YES"),
        ),
    ),
    "H-T01-03-install-magic-keyboard-before.sh": Highlight(
        "install_magic_keyboard_referenceobject.sh",
        (
            Span(
                "# This is the current Xcode 27 / visionOS 27 sample linked from Apple's",
                'archive_member="Reference Objects/Apple_Magic_Keyboard.referenceobject"',
            ),
            Span(
                "temporary_directory=$(mktemp -d /private/tmp/SpatialObjectDrums-MagicKeyboard.XXXXXX)",
                'mkdir -p "$extracted_directory" "$compiled_directory"',
            ),
            Span(
                'echo "Apple 공식 Xcode 27 / visionOS 27 Object Tracking 샘플을 다운로드합니다."',
                "fi",
            ),
            Span(
                'unzip -j -q "$archive" "$archive_member" -d "$extracted_directory"',
                "}",
            ),
        ),
    ),
    "H-T01-04-train-reference-object-before.sh": Highlight(
        "train_reference_object.sh",
        (
            Span("usage() {", "}"),
            Span('source_model=""', "force=0"),
            Span(
                'echo "Create ML Object Tracking 학습을 시작합니다."',
                'DEVELOPER_DIR="$developer_directory" /usr/bin/xcrun createml objecttracker "$@"',
            ),
            Span(
                '[ -s "$trained" ] || {',
                'echo "학습 및 호환성 검사 완료: $output"',
            ),
        ),
    ),
    "H-T01-05-Info-before.plist": Highlight(
        "Info.plist",
        (
            Span(
                "\t<key>NSHandsTrackingUsageDescription</key>",
                "\t<string>Apple Magic Keyboard의 위치와 자세를 추적해 가상 타격 영역을 표시합니다.</string>",
            ),
        ),
    ),
    "H-T01-06-SpatialObjectDrumsApp-before.swift": Highlight(
        "SpatialObjectDrumsApp.swift",
        (
            Span("    @State private var model = DrumAppModel()"),
            Span(
                "    var body: some Scene {",
                "        .immersionStyle(selection: .constant(.mixed), in: .mixed)",
            ),
        ),
    ),
    "H-T01-07-ContentView-before.swift": Highlight(
        "ContentView.swift",
        (
            Span(
                "    @Environment(DrumAppModel.self) private var model",
                "    var body: some View {",
                include_end=False,
            ),
            Span(
                "            Button(buttonTitle) {",
                "        .padding(40)",
                include_end=False,
            ),
            Span(
                "    private var buttonTitle: String {",
                "        return model.isImmersiveSpaceOpen ? \"Stop Drumming\" : \"Start Drumming\"",
            )
        ),
    ),

    # Tutorial 02 — reference object and ObjectAnchor lifecycle.
    "H-T02-S01-P01-DrumAppModel-before.swift": Highlight(
        "DrumAppModel.swift",
        (Span("    private func loadReferenceObjects() async throws -> [ReferenceObject] {", "    private func consumeObjectUpdates(", include_end=False),),
    ),
    "H-T02-S01-P02-DrumAppModel-before.swift": Highlight(
        "DrumAppModel.swift",
        (Span("    func prepareForImmersiveSpace() async -> Bool {", "    func start(in root: Entity) async {", include_end=False),),
    ),
    "H-T02-S01-P03-DrumAppModel-before.swift": Highlight(
        "DrumAppModel.swift",
        (Span("    func start(in root: Entity) async {", "    func stop() {", include_end=False),),
    ),
    "H-T02-S02-P01-DrumAppModel-before.swift": Highlight(
        "DrumAppModel.swift",
        (Span("            case .added:", "            case .updated:", include_end=False),),
    ),
    "H-T02-S02-P02-TrackedDrum-before.swift": Highlight(
        "TrackedDrum.swift",
        (Span("    func update(anchor: ObjectAnchor) {", "    func hitIntensity(from previousWorld: SIMD3<Float>, to currentWorld: SIMD3<Float>) -> Float? {", include_end=False),),
    ),
    "H-T02-S02-P03-DrumAppModel-before.swift": Highlight(
        "DrumAppModel.swift",
        (Span("            case .removed:", "        }", include_end=False),),
    ),
    "H-T02-S03-P01-TrackedDrum-before.swift": Highlight(
        "TrackedDrum.swift",
        (
            Span("    private static let feedbackHeight: Float = 0.004"),
            Span("    private let feedback: ModelEntity", "    private let boundsMax: SIMD3<Float>"),
            Span("        let size = boundsMax - boundsMin", "        )"),
            Span("        feedback.position = [center.x, hitPlaneY, center.z]"),
            Span("        entity.addChild(feedback)", "        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)"),
        ),
    ),
    "H-T02-S03-P02-DrumProfile-before.swift": Highlight(
        "DrumProfile.swift",
        (
            Span(
                "    static func forReferenceObject(named name: String) -> DrumProfile {",
                "            .lowercased()",
            ),
            Span(
                '        if normalizedName.contains("magickeyboard") {',
                "        }",
            ),
        ),
    ),

    # Tutorial 03 — hand motion, hit testing, audio, and lifecycle.
    "H-T03-01-IndexTip-before.swift": Highlight(
        "DrumAppModel.swift",
        (Span("            let joint = skeleton.joint(.indexFingerTip)", "            defer { previousTips[hand.chirality] = current }", include_end=False),),
    ),
    "H-T03-02-ChiralityHistory-before.swift": Highlight(
        "DrumAppModel.swift",
        (
            Span("    @ObservationIgnored private var previousTips: [HandAnchor.Chirality: SIMD3<Float>] = [:]"),
            Span("            guard hand.isTracked,", "            }"),
            Span("            guard joint.isTracked else {", "            }"),
            Span("            defer { previousTips[hand.chirality] = current }"),
            Span("            guard let previous = previousTips[hand.chirality] else { continue }"),
        ),
    ),
    "H-T03-03-KeyboardLocal-before.swift": Highlight(
        "TrackedDrum.swift",
        (Span("    func hitIntensity(from previousWorld: SIMD3<Float>, to currentWorld: SIMD3<Float>) -> Float? {", "        let top = hitPlaneY", include_end=False),),
    ),
    "H-T03-04-HitPlane-before.swift": Highlight(
        "TrackedDrum.swift",
        (
            Span("    private static let strikePlaneOffset: Float = 0.012"),
            Span("    private static let minimumHitIntensity: Float = 0.15"),
            Span("    private let hitPlaneY: Float"),
            Span("        hitPlaneY = anchor.boundingBox.max.y + Self.strikePlaneOffset"),
            Span("        feedback.position = [center.x, hitPlaneY, center.z]"),
            Span("        let top = hitPlaneY", "        return min(max(verticalDistance / 0.04, Self.minimumHitIntensity), 1)"),
        ),
    ),
    "H-T03-05-Cooldown-before.swift": Highlight(
        "DrumAppModel.swift",
        (
            Span("    @ObservationIgnored private var lastHitAt: [UUID: ContinuousClock.Instant] = [:]"),
            Span("                    let now = ContinuousClock.now", "                    lastHitAt[drum.id] = now")
        ),
    ),
    "H-T03-06-SpatialAudio-before.swift": Highlight(
        "TrackedDrum.swift",
        (
            Span("    private let audio: AudioFileResource"),
            Span("        entity.spatialAudio = SpatialAudioComponent(gain: -6)", "        audio = try await AudioFileResource(named: selectedProfile.audioResource)"),
            Span("        let normalizedIntensity = min(", "        entity.playAudio(audio)"),
        ),
    ),
    "H-T03-07-OpacityFeedback-before.swift": Highlight(
        "TrackedDrum.swift",
        (
            Span("    private static let restingOpacity: Float = 0.42", "    private static let hitOpacity: Float = 0.9"),
            Span("            materials: [SimpleMaterial(color: .systemGreen, isMetallic: false)]"),
            Span("        feedback.components.set(OpacityComponent(opacity: Self.restingOpacity))"),
            Span("        feedback.components.set(OpacityComponent(opacity: Self.hitOpacity))", "        }")
        ),
    ),
    "H-T03-08-RealityLifecycle-before.swift": Highlight(
        "DrumRealityView.swift",
        (
            Span("    @State private var root = Entity()"),
            Span("        RealityView { content in", "        .task { await model.start(in: root) }"),
            Span("        .onDisappear { model.stop() }"),
        ),
    ),
    "H-T03-09-FailureHandling-before.swift": Highlight(
        "DrumAppModel.swift",
        (
            Span("    var errorMessage: String?"),
            Span("        } catch is CancellationError {", "        }", start_occurrence=1),
            Span("        } catch is CancellationError {", "        }", start_occurrence=2),
            Span("    private func clearTrackingContent() {", "    private func resetTrackingSession() {", include_end=False),
            Span("                } catch {", "                }"),
            Span("    private func consumeSessionEvents(from session: ARKitSession, runID: UUID) async {", "    private func consumeHandUpdates(from provider: HandTrackingProvider, runID: UUID) async {", include_end=False),
            Span("enum DrumError: LocalizedError {", through_end=True),
        ),
    ),
}


def unique_index(lines: list[str], token: str, start_at: int = 0) -> int:
    matches = [
        index
        for index in range(start_at, len(lines))
        if lines[index].rstrip("\r\n") == token
    ]
    if len(matches) != 1:
        raise ValueError(f"Expected one occurrence of {token!r}; found {len(matches)}")
    return matches[0]


def occurrence_index(lines: list[str], token: str, occurrence: int) -> int:
    if occurrence < 1:
        raise ValueError(f"Occurrence must be positive for {token!r}")
    matches = [
        index
        for index, line in enumerate(lines)
        if line.rstrip("\r\n") == token
    ]
    if len(matches) < occurrence:
        raise ValueError(
            f"Expected occurrence {occurrence} of {token!r}; found {len(matches)}"
        )
    return matches[occurrence - 1]


def first_index(lines: list[str], token: str, start_at: int = 0) -> int:
    for index in range(start_at, len(lines)):
        if lines[index].rstrip("\r\n") == token:
            return index
    raise ValueError(f"Expected an occurrence of {token!r} after line {start_at + 1}")


def masked_content(content: str, spans: tuple[Span, ...]) -> str:
    lines = content.splitlines(keepends=True)
    masked: set[int] = set()

    for span in spans:
        if span.start is None and span.end is None:
            masked.update(range(len(lines)))
            continue

        if span.start is None:
            start = 0
        elif span.start_occurrence is not None:
            start = occurrence_index(lines, span.start, span.start_occurrence)
        else:
            start = unique_index(lines, span.start)

        if span.end is None:
            end = len(lines) - 1 if span.through_end else start
        elif span.end == span.start:
            end = start
        else:
            end = first_index(lines, span.end, start)
            if not span.include_end:
                end -= 1

        if end < start:
            raise ValueError(f"Invalid span {span}")
        masked.update(range(start, end + 1))

    for index in masked:
        lines[index] = "\n" if lines[index].endswith("\n") else ""
    if len(masked) == len(lines):
        return ""
    while lines and not lines[-1].strip():
        lines.pop()
    return "".join(lines)


def final_snapshot_name(previous_name: str) -> str:
    prefix, marker, suffix = previous_name.partition("-before")
    if not marker:
        raise ValueError(f"Highlight baseline name lacks '-before': {previous_name}")
    return f"{prefix}-final{suffix}"


CODE_DIRECTIVE = re.compile(
    r'@Code\(name:\s*"(?P<name>[^"]+)",\s*'
    r'file:\s*"(?P<file>[^"]+)",\s*'
    r'previousFile:\s*"(?P<previous_file>[^"]+)"\)'
)


def tutorial_references() -> list[CodeReference]:
    references: list[CodeReference] = []
    for tutorial in sorted(TUTORIALS.glob("*.tutorial")):
        for line_number, line in enumerate(
            tutorial.read_text(encoding="utf-8").splitlines(), start=1
        ):
            if "@Code(" not in line:
                continue
            match = CODE_DIRECTIVE.search(line)
            if match is None:
                raise ValueError(
                    f"Unsupported @Code format: {tutorial.name}:{line_number}"
                )
            references.append(
                CodeReference(
                    tutorial=tutorial.name,
                    line=line_number,
                    name=match.group("name"),
                    file=match.group("file"),
                    previous_file=match.group("previous_file"),
                )
            )
    return references


def verify_configuration() -> None:
    references = tutorial_references()
    final_files = [reference.file for reference in references]
    previous_files = [reference.previous_file for reference in references]

    if len(final_files) != len(set(final_files)):
        raise ValueError("Every @Code step must use a unique final snapshot file")
    if len(previous_files) != len(set(previous_files)):
        raise ValueError("Every @Code step must use a unique previousFile baseline")

    missing_highlights = set(previous_files) - HIGHLIGHTS.keys()
    orphan_highlights = HIGHLIGHTS.keys() - set(previous_files)
    if missing_highlights:
        raise ValueError(f"Missing highlight definitions: {sorted(missing_highlights)}")
    if orphan_highlights:
        raise ValueError(f"Unused highlight definitions: {sorted(orphan_highlights)}")

    for reference in references:
        highlight = HIGHLIGHTS[reference.previous_file]
        if highlight.resource not in RESOURCE_SOURCES:
            raise ValueError(
                f"Missing source mapping for {highlight.resource}: "
                f"{reference.tutorial}:{reference.line}"
            )
        expected_final = final_snapshot_name(reference.previous_file)
        if reference.file != expected_final:
            raise ValueError(
                f"Final/previous pair mismatch at {reference.tutorial}:{reference.line}; "
                f"expected file {expected_final!r}"
            )
        if reference.name != highlight.resource:
            raise ValueError(
                f"Displayed name must remain {highlight.resource!r} at "
                f"{reference.tutorial}:{reference.line}"
            )


def synchronize(check: bool) -> int:
    verify_configuration()
    failures: list[str] = []
    RESOURCES.mkdir(parents=True, exist_ok=True)

    for resource_name, source_path in RESOURCE_SOURCES.items():
        expected = source_path.read_text(encoding="utf-8")
        destination = RESOURCES / resource_name
        if check:
            if not destination.exists() or destination.read_text(encoding="utf-8") != expected:
                failures.append(f"out of sync: {resource_name}")
        else:
            destination.write_text(expected, encoding="utf-8")

    for previous_name, highlight in HIGHLIGHTS.items():
        source = RESOURCE_SOURCES[highlight.resource].read_text(encoding="utf-8")
        final_destination = RESOURCES / final_snapshot_name(previous_name)
        previous_destination = RESOURCES / previous_name
        if check:
            if not final_destination.exists() or final_destination.read_text(encoding="utf-8") != source:
                failures.append(f"out of sync: {final_destination.name}")
        else:
            final_destination.write_text(source, encoding="utf-8")

        expected_previous = masked_content(source, highlight.spans)
        if check:
            if not previous_destination.exists() or previous_destination.read_text(encoding="utf-8") != expected_previous:
                failures.append(f"out of sync: {previous_name}")
        else:
            previous_destination.write_text(expected_previous, encoding="utf-8")

    if failures:
        for failure in failures:
            print(failure, file=sys.stderr)
        print("Run make sync-docc-code.", file=sys.stderr)
        return 1

    action = "Verified" if check else "Synchronized"
    print(
        f"{action} {len(RESOURCE_SOURCES)} canonical files, "
        f"{len(HIGHLIGHTS)} unique final snapshots, and "
        f"{len(HIGHLIGHTS)} highlight baselines."
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="verify without writing files")
    arguments = parser.parse_args()
    try:
        return synchronize(arguments.check)
    except (OSError, ValueError) as error:
        print(f"DocC highlight generation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
