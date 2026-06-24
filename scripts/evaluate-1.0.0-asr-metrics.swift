#!/usr/bin/env swift

import Foundation

struct MetricsFile: Decodable {
    let samples: [Sample]
    let thresholds: Thresholds?
}

struct Thresholds: Decodable {
    let maxAverageCER: Double?
    let maxLanguageMisclassificationRate: Double?
    let fastStopToOutputP50Ms: Double?
    let fastStopToOutputP95Ms: Double?
    let highAccuracyStopToOutputP50Ms: Double?
    let highAccuracyStopToOutputP95Ms: Double?
}

struct Sample: Decodable {
    let id: String
    let category: String
    let backend: String
    let expectedLanguage: String
    let reference: String
    let transcript: String
    let firstFeedbackLatencyMs: Double?
    let firstPreviewLatencyMs: Double?
    let stopToOutputLatencyMs: Double?
    let totalCompletionLatencyMs: Double?
    let peakCPUPercent: Double?
    let memoryMB: Double?
    let modelName: String?
    let prewarmed: Bool?
    let notes: String?
}

struct SampleMetrics {
    let sample: Sample
    let cer: Double
    let isLanguageMisclassified: Bool
}

let arguments = CommandLine.arguments.dropFirst()
let strictMode = arguments.contains("--strict")
let pathArguments = arguments.filter { !$0.hasPrefix("--") }

guard let metricsPath = pathArguments.first else {
    fputs("Usage: evaluate-1.0.0-asr-metrics.swift [--strict] <metrics.json>\n", stderr)
    exit(64)
}

let url = URL(fileURLWithPath: metricsPath)

do {
    let data = try Data(contentsOf: url)
    let metricsFile = try JSONDecoder().decode(MetricsFile.self, from: data)
    let summary = evaluate(metricsFile)
    print(summary.report)

    if strictMode, !summary.failures.isEmpty {
        for failure in summary.failures {
            fputs("error: \(failure)\n", stderr)
        }
        exit(1)
    }
} catch {
    fputs("error: failed to evaluate ASR metrics: \(error)\n", stderr)
    exit(1)
}

struct EvaluationSummary {
    let report: String
    let failures: [String]
}

func evaluate(_ file: MetricsFile) -> EvaluationSummary {
    var failures: [String] = []

    let completedSamples = file.samples.filter {
        !$0.reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !$0.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    let pendingSampleCount = file.samples.count - completedSamples.count

    guard !file.samples.isEmpty else {
        return EvaluationSummary(
            report: "ReadyType ASR metrics: no samples found.",
            failures: ["metrics file must include at least one sample"]
        )
    }
    guard !completedSamples.isEmpty else {
        return EvaluationSummary(
            report: "ReadyType ASR metrics: samples=\(file.samples.count) completed=0 pending=\(pendingSampleCount)",
            failures: ["metrics file must include at least one completed sample with reference and transcript"]
        )
    }

    if pendingSampleCount > 0 {
        failures.append("\(pendingSampleCount) sample(s) are missing reference or transcript")
    }

    let sampleMetrics = completedSamples.map { sample in
        SampleMetrics(
            sample: sample,
            cer: characterErrorRate(reference: sample.reference, hypothesis: sample.transcript),
            isLanguageMisclassified: isLanguageMisclassified(sample)
        )
    }

    let chineseMetrics = sampleMetrics.filter { $0.sample.expectedLanguage.lowercased().hasPrefix("zh") }
    let misclassifiedCount = chineseMetrics.filter(\.isLanguageMisclassified).count
    let misclassificationRate = chineseMetrics.isEmpty ? 0 : Double(misclassifiedCount) / Double(chineseMetrics.count)
    let averageCER = sampleMetrics.map(\.cer).reduce(0, +) / Double(sampleMetrics.count)

    var lines: [String] = []
    lines.append("ReadyType ASR metrics: samples=\(file.samples.count) completed=\(sampleMetrics.count) pending=\(pendingSampleCount)")
    lines.append(String(format: "Average CER: %.4f", averageCER))
    lines.append(
        String(
            format: "Chinese language misclassification: %d/%d = %.4f",
            misclassifiedCount,
            chineseMetrics.count,
            misclassificationRate
        )
    )

    appendLatencyReport(
        name: "Input feedback latency",
        values: completedSamples.compactMap(\.firstFeedbackLatencyMs),
        lines: &lines
    )
    appendLatencyReport(
        name: "First preview latency",
        values: completedSamples.compactMap(\.firstPreviewLatencyMs),
        lines: &lines
    )
    appendLatencyReport(
        name: "Stop-to-output latency",
        values: completedSamples.compactMap(\.stopToOutputLatencyMs),
        lines: &lines
    )
    appendLatencyReport(
        name: "Total completion latency",
        values: completedSamples.compactMap(\.totalCompletionLatencyMs),
        lines: &lines
    )

    for backend in Set(completedSamples.map(\.backend)).sorted() {
        let backendSamples = completedSamples.filter { $0.backend == backend }
        appendLatencyReport(
            name: "\(backend) stop-to-output latency",
            values: backendSamples.compactMap(\.stopToOutputLatencyMs),
            lines: &lines
        )
    }

    let peakCPU = completedSamples.compactMap(\.peakCPUPercent).max()
    let peakMemory = completedSamples.compactMap(\.memoryMB).max()
    if let peakCPU {
        lines.append(String(format: "Peak CPU: %.1f%%", peakCPU))
    } else {
        lines.append("Peak CPU: not recorded")
    }
    if let peakMemory {
        lines.append(String(format: "Peak memory: %.1f MB", peakMemory))
    } else {
        lines.append("Peak memory: not recorded")
    }

    for metric in sampleMetrics {
        lines.append(
            String(
                format: "- %@ [%@/%@] CER=%.4f misclassified=%@",
                metric.sample.id,
                metric.sample.category,
                metric.sample.backend,
                metric.cer,
                metric.isLanguageMisclassified ? "yes" : "no"
            )
        )
    }

    if let thresholds = file.thresholds {
        check(averageCER, thresholds.maxAverageCER, label: "average CER", failures: &failures)
        check(misclassificationRate, thresholds.maxLanguageMisclassificationRate, label: "language misclassification rate", failures: &failures)
        checkPercentile(
            completedSamples.filter { $0.backend == "fast" }.compactMap(\.stopToOutputLatencyMs),
            p: 0.50,
            threshold: thresholds.fastStopToOutputP50Ms,
            label: "fast stop-to-output P50",
            failures: &failures
        )
        checkPercentile(
            completedSamples.filter { $0.backend == "fast" }.compactMap(\.stopToOutputLatencyMs),
            p: 0.95,
            threshold: thresholds.fastStopToOutputP95Ms,
            label: "fast stop-to-output P95",
            failures: &failures
        )
        checkPercentile(
            completedSamples.filter { $0.backend == "highAccuracy" }.compactMap(\.stopToOutputLatencyMs),
            p: 0.50,
            threshold: thresholds.highAccuracyStopToOutputP50Ms,
            label: "high-accuracy stop-to-output P50",
            failures: &failures
        )
        checkPercentile(
            completedSamples.filter { $0.backend == "highAccuracy" }.compactMap(\.stopToOutputLatencyMs),
            p: 0.95,
            threshold: thresholds.highAccuracyStopToOutputP95Ms,
            label: "high-accuracy stop-to-output P95",
            failures: &failures
        )
    }

    return EvaluationSummary(report: lines.joined(separator: "\n"), failures: failures)
}

func appendLatencyReport(name: String, values: [Double], lines: inout [String]) {
    guard !values.isEmpty else {
        lines.append("\(name): not recorded")
        return
    }

    lines.append(
        String(
            format: "%@: p50=%.1fms p95=%.1fms max=%.1fms",
            name,
            percentile(values, p: 0.50),
            percentile(values, p: 0.95),
            values.max() ?? 0
        )
    )
}

func characterErrorRate(reference: String, hypothesis: String) -> Double {
    let referenceCharacters = Array(normalizedForCER(reference))
    let hypothesisCharacters = Array(normalizedForCER(hypothesis))

    guard !referenceCharacters.isEmpty else {
        return hypothesisCharacters.isEmpty ? 0 : 1
    }

    return Double(levenshtein(referenceCharacters, hypothesisCharacters)) / Double(referenceCharacters.count)
}

func normalizedForCER(_ value: String) -> String {
    value
        .lowercased()
        .filter { !$0.isWhitespace && !$0.isNewline }
}

func levenshtein<T: Equatable>(_ lhs: [T], _ rhs: [T]) -> Int {
    if lhs.isEmpty { return rhs.count }
    if rhs.isEmpty { return lhs.count }

    var previous = Array(0...rhs.count)
    var current = Array(repeating: 0, count: rhs.count + 1)

    for i in 1...lhs.count {
        current[0] = i
        for j in 1...rhs.count {
            let deletion = previous[j] + 1
            let insertion = current[j - 1] + 1
            let substitution = previous[j - 1] + (lhs[i - 1] == rhs[j - 1] ? 0 : 1)
            current[j] = min(deletion, insertion, substitution)
        }
        previous = current
    }

    return previous[rhs.count]
}

func isLanguageMisclassified(_ sample: Sample) -> Bool {
    guard sample.expectedLanguage.lowercased().hasPrefix("zh") else {
        return false
    }

    let chineseCount = sample.transcript.unicodeScalars.filter(isChineseScalar).count
    let latinCount = sample.transcript.unicodeScalars.filter(isLatinLetter).count
    let scriptCount = chineseCount + latinCount

    if scriptCount == 0 {
        return true
    }
    if chineseCount == 0, latinCount >= 3 {
        return true
    }
    if scriptCount >= 8 {
        let chineseRatio = Double(chineseCount) / Double(scriptCount)
        return chineseRatio < 0.15 && latinCount > chineseCount * 4
    }
    return false
}

func isChineseScalar(_ scalar: UnicodeScalar) -> Bool {
    switch scalar.value {
    case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2A6DF, 0x2A700...0x2B73F, 0x2B740...0x2B81F, 0x2B820...0x2CEAF:
        return true
    default:
        return false
    }
}

func isLatinLetter(_ scalar: UnicodeScalar) -> Bool {
    (0x41...0x5A).contains(scalar.value) || (0x61...0x7A).contains(scalar.value)
}

func percentile(_ values: [Double], p: Double) -> Double {
    let sorted = values.sorted()
    guard !sorted.isEmpty else { return 0 }
    let index = max(0, min(sorted.count - 1, Int(ceil(Double(sorted.count) * p)) - 1))
    return sorted[index]
}

func check(_ value: Double, _ threshold: Double?, label: String, failures: inout [String]) {
    guard let threshold else { return }
    if value > threshold {
        failures.append(String(format: "%@ %.4f exceeds threshold %.4f", label, value, threshold))
    }
}

func checkPercentile(_ values: [Double], p: Double, threshold: Double?, label: String, failures: inout [String]) {
    guard let threshold else { return }
    guard !values.isEmpty else {
        failures.append("\(label) cannot be evaluated because no samples were recorded")
        return
    }

    let value = percentile(values, p: p)
    if value > threshold {
        failures.append(String(format: "%@ %.1fms exceeds threshold %.1fms", label, value, threshold))
    }
}
