import XCTest

final class ReleaseGateScriptTests: XCTestCase {
    func testOnePointZeroReleaseGateRunsContextualVocabularyBenchmark() throws {
        let root = repositoryRoot()
        let benchmarkScript = root.appendingPathComponent("scripts/benchmark-1.0.0-contextual-vocabulary.sh")
        let asrMetricsScript = root.appendingPathComponent("scripts/evaluate-1.0.0-asr-metrics.swift")
        let asrMetricsRecordScript = root.appendingPathComponent("scripts/record-1.0.0-asr-metrics.swift")
        let uiAcceptanceScript = root.appendingPathComponent("scripts/verify-1.0.0-ui.sh")
        let commonWordsUIScript = root.appendingPathComponent("scripts/verify-1.0.0-common-words-ui.sh")
        let visualAcceptanceScript = root.appendingPathComponent("scripts/verify-1.0.0-visual-acceptance.sh")
        let localSpeechModelScript = root.appendingPathComponent("scripts/verify-1.0.0-local-speech-model.sh")
        let textEditPasteScript = root.appendingPathComponent("scripts/verify-1.2-textedit-paste.sh")
        let dmgPackageScript = root.appendingPathComponent("scripts/package-dmg.sh")
        let asrMetricsTemplate = root.appendingPathComponent("docs/versions/1.0.0/plans/readytype-1.0.0-asr-metrics-template.json")
        let releaseGate = root.appendingPathComponent("scripts/verify-1.0.0-release-local.sh")
        let ciWorkflow = root.appendingPathComponent(".github/workflows/ci.yml")
        let releaseWorkflow = root.appendingPathComponent(".github/workflows/release.yml")
        let sensitiveInformationScanner = root.appendingPathComponent("scripts/check-sensitive-info.py")
        let releaseStateVerifier = root.appendingPathComponent("scripts/verify-release-state.sh")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: benchmarkScript.path),
            "1.0.0 release gate needs a repeatable contextual vocabulary latency benchmark."
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: asrMetricsScript.path),
            "1.0.0 release gate needs a repeatable real ASR metrics evaluator."
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: asrMetricsRecordScript.path),
            "1.0.0 manual acceptance needs a repeatable local ASR metrics recorder."
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: uiAcceptanceScript.path),
            "1.0.0 release gate needs a repeatable GUI UI text acceptance script."
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: commonWordsUIScript.path),
            "1.0.0 release gate needs a repeatable Common Words UI refresh acceptance script."
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: visualAcceptanceScript.path),
            "1.0.0 release gate needs a repeatable visual acceptance screenshot script."
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: localSpeechModelScript.path),
            "1.0.0 release gate needs an explicit real local speech-package acceptance script."
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: textEditPasteScript.path),
            "1.0.0 release gate needs a repeatable TextEdit paste acceptance script."
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: dmgPackageScript.path),
            "1.0.0 release gate needs a repeatable DMG packaging script for GitHub downloads."
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: asrMetricsTemplate.path),
            "1.0.0 real ASR metrics need a stable record template."
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: releaseWorkflow.path),
            "Version tags need an automated GitHub Release workflow."
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: sensitiveInformationScanner.path),
            "CI and release jobs need a shared sensitive-information scanner."
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: releaseStateVerifier.path),
            "Published releases need a repeatable remote-state verifier."
        )

        let releaseGateSource = try String(contentsOf: releaseGate, encoding: .utf8)
        XCTAssertTrue(
            releaseGateSource.contains("scripts/benchmark-1.0.0-contextual-vocabulary.sh"),
            "1.0.0 release gate must run the contextual vocabulary latency benchmark."
        )
        XCTAssertTrue(
            releaseGateSource.contains("RUN_ASR_METRICS"),
            "1.0.0 release gate must expose the real ASR metrics acceptance switch."
        )
        XCTAssertTrue(
            releaseGateSource.contains("scripts/evaluate-1.0.0-asr-metrics.swift"),
            "1.0.0 release gate must run the real ASR metrics evaluator when enabled."
        )
        XCTAssertTrue(
            releaseGateSource.contains("RUN_UI_ACCEPTANCE"),
            "1.0.0 release gate must expose the GUI UI text acceptance switch."
        )
        XCTAssertTrue(
            releaseGateSource.contains("scripts/verify-1.0.0-ui.sh"),
            "1.0.0 release gate must run the GUI UI text acceptance script when enabled."
        )
        XCTAssertTrue(
            releaseGateSource.contains("RUN_COMMON_WORDS_UI"),
            "1.0.0 release gate must expose the Common Words UI refresh acceptance switch."
        )
        XCTAssertTrue(
            releaseGateSource.contains("scripts/verify-1.0.0-common-words-ui.sh"),
            "1.0.0 release gate must run the Common Words UI refresh acceptance script when enabled."
        )
        XCTAssertTrue(
            releaseGateSource.contains("RUN_VISUAL_ACCEPTANCE"),
            "1.0.0 release gate must expose the visual screenshot acceptance switch."
        )
        XCTAssertTrue(
            releaseGateSource.contains("scripts/verify-1.0.0-visual-acceptance.sh"),
            "1.0.0 release gate must run the visual acceptance script when enabled."
        )
        XCTAssertTrue(
            releaseGateSource.contains("RUN_LOCAL_SPEECH_MODEL"),
            "1.0.0 release gate must expose the real local speech-package acceptance switch."
        )
        XCTAssertTrue(
            releaseGateSource.contains("scripts/verify-1.0.0-local-speech-model.sh"),
            "1.0.0 release gate must run the local speech-package acceptance script when enabled."
        )
        XCTAssertTrue(
            releaseGateSource.contains("scripts/package-dmg.sh"),
            "1.0.0 release gate must package a DMG alongside the release zip."
        )

        let ciWorkflowSource = try String(contentsOf: ciWorkflow, encoding: .utf8)
        XCTAssertTrue(
            ciWorkflowSource.contains("scripts/package-dmg.sh"),
            "GitHub Actions should produce a downloadable DMG artifact for each release-candidate build."
        )
        XCTAssertTrue(
            ciWorkflowSource.contains("ReadyType.dmg"),
            "GitHub Actions should upload the generated DMG artifact."
        )
        XCTAssertTrue(
            ciWorkflowSource.contains("scripts/check-sensitive-info.py"),
            "CI should run the shared sensitive-information scanner."
        )

        let releaseWorkflowSource = try String(contentsOf: releaseWorkflow, encoding: .utf8)
        XCTAssertTrue(releaseWorkflowSource.contains("tags:"))
        XCTAssertTrue(releaseWorkflowSource.contains("Validate tag and app version"))
        XCTAssertTrue(releaseWorkflowSource.contains("scripts/check-sensitive-info.py"))
        XCTAssertTrue(releaseWorkflowSource.contains("Validate analytics release configuration"))
        XCTAssertTrue(releaseWorkflowSource.contains("vars.READYTYPE_TELEMETRYDECK_APP_ID"))
        XCTAssertFalse(releaseWorkflowSource.contains("READYTYPE_TELEMETRYDECK_TEST_MODE"))
        XCTAssertTrue(releaseWorkflowSource.contains("scripts/package-app.sh"))
        XCTAssertTrue(releaseWorkflowSource.contains("scripts/package-dmg.sh"))
        XCTAssertTrue(releaseWorkflowSource.contains("SHA256SUMS.txt"))
        XCTAssertTrue(releaseWorkflowSource.contains("gh release create"))

        let releaseStateVerifierSource = try String(contentsOf: releaseStateVerifier, encoding: .utf8)
        XCTAssertTrue(releaseStateVerifierSource.contains("releases/latest"))
        XCTAssertTrue(releaseStateVerifierSource.contains("ReadyType.app.zip"))
        XCTAssertTrue(releaseStateVerifierSource.contains("ReadyType.dmg"))
        XCTAssertTrue(releaseStateVerifierSource.contains("SHA256SUMS.txt"))
        XCTAssertTrue(releaseStateVerifierSource.contains("BLACK_BOX_TESTS.zh-CN.md"))

        let visualAcceptanceSource = try String(contentsOf: visualAcceptanceScript, encoding: .utf8)
        XCTAssertTrue(
            visualAcceptanceSource.contains("正在听，"),
            "Visual acceptance HUD fixtures should use voice-input copy instead of recorder copy."
        )
        XCTAssertFalse(visualAcceptanceSource.contains("正在听你说话"))
        XCTAssertTrue(
            visualAcceptanceSource.contains("已输入"),
            "Visual acceptance HUD fixtures should verify input-focused success copy."
        )
        XCTAssertFalse(
            visualAcceptanceSource.contains("正在录音"),
            "Visual acceptance HUD fixtures should not regress to recorder copy."
        )

        let textEditPasteSource = try String(contentsOf: textEditPasteScript, encoding: .utf8)
        XCTAssertTrue(
            textEditPasteSource.contains("TextEdit is already running with open documents"),
            "TextEdit paste acceptance must fail before inserting when user TextEdit documents are open."
        )

        let asrMetricsRecordSource = try String(contentsOf: asrMetricsRecordScript, encoding: .utf8)
        XCTAssertTrue(
            asrMetricsRecordSource.contains("readytype-1.0.0-asr-metrics-record.local.json"),
            "The ASR metrics recorder should default to a local-only metrics record."
        )
        XCTAssertTrue(
            asrMetricsRecordSource.contains("readytype-1.0.0-asr-metrics-template.json"),
            "The ASR metrics recorder should reuse the release thresholds from the template."
        )
        XCTAssertTrue(
            asrMetricsRecordSource.contains("scripts/evaluate-1.0.0-asr-metrics.swift"),
            "The ASR metrics recorder should hand newly recorded samples to the evaluator."
        )
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
