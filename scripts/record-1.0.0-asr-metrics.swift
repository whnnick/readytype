#!/usr/bin/env swift

import Foundation
import Darwin

struct MetricsFile: Codable {
    var thresholds: Thresholds?
    var samples: [Sample]
}

struct Thresholds: Codable {
    var maxAverageCER: Double?
    var maxLanguageMisclassificationRate: Double?
    var fastStopToOutputP50Ms: Double?
    var fastStopToOutputP95Ms: Double?
    var highAccuracyStopToOutputP50Ms: Double?
    var highAccuracyStopToOutputP95Ms: Double?
}

struct Sample: Codable {
    var id: String
    var category: String
    var backend: String
    var expectedLanguage: String
    var reference: String
    var transcript: String
    var firstFeedbackLatencyMs: Double?
    var firstPreviewLatencyMs: Double?
    var stopToOutputLatencyMs: Double?
    var totalCompletionLatencyMs: Double?
    var peakCPUPercent: Double?
    var memoryMB: Double?
    var modelName: String?
    var prewarmed: Bool?
    var notes: String?
}

struct Arguments {
    var metricsPath = "docs/versions/1.0.0/plans/readytype-1.0.0-asr-metrics-record.local.json"
    var evaluate = true
    var strict = false
    var help = false
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let templateURL = root.appendingPathComponent("docs/versions/1.0.0/plans/readytype-1.0.0-asr-metrics-template.json")
let evaluatorURL = root.appendingPathComponent("scripts/evaluate-1.0.0-asr-metrics.swift")

do {
    let arguments = try parseArguments(Array(CommandLine.arguments.dropFirst()))
    if arguments.help {
        printUsage()
        exit(0)
    }

    let metricsURL = URL(fileURLWithPath: arguments.metricsPath, relativeTo: root).standardizedFileURL
    var metricsFile = try loadOrCreateMetricsFile(at: metricsURL)

    print("ReadyType 1.0.0 ASR 指标记录")
    print("只写入本机 .local.json；不要提交包含私人口述内容的记录文件。")
    print("")

    let category = prompt(
        "样本类型",
        defaultValue: "chat",
        allowedValues: ["chat", "email", "longForm", "technicalTerms", "translation", "generic"]
    )
    let backend = prompt(
        "识别方式",
        defaultValue: "automatic",
        allowedValues: ["fast", "highAccuracy", "automatic"]
    )
    let expectedLanguage = prompt("主语言", defaultValue: "zh-CN")
    let sampleID = prompt("样本 ID", defaultValue: defaultSampleID(category: category, backend: backend))
    let reference = prompt("预先写定的口述原文", required: true)
    let transcript = prompt("ReadyType 真实识别出的原始转写", required: true)
    let firstFeedbackLatencyMs = promptOptionalDouble("输入反馈延迟 ms")
    let firstPreviewLatencyMs = promptOptionalDouble("首段可读文本延迟 ms")
    let stopToOutputLatencyMs = promptOptionalDouble("停止到最终文本可输出 ms")
    let totalCompletionLatencyMs = promptOptionalDouble("开始说话到已粘贴或复制完成 ms")
    let peakCPUPercent = promptOptionalDouble("峰值 CPU %")
    let memoryMB = promptOptionalDouble("峰值内存 MB")
    let modelName = promptOptionalString("识别方式备注", defaultValue: defaultModelName(for: backend))
    let prewarmed = promptOptionalBool("高精度是否已提前准备", defaultValue: defaultPrewarmValue(for: backend))
    let notes = promptOptionalString("备注")

    let sample = Sample(
        id: sampleID,
        category: category,
        backend: backend,
        expectedLanguage: expectedLanguage,
        reference: reference,
        transcript: transcript,
        firstFeedbackLatencyMs: firstFeedbackLatencyMs,
        firstPreviewLatencyMs: firstPreviewLatencyMs,
        stopToOutputLatencyMs: stopToOutputLatencyMs,
        totalCompletionLatencyMs: totalCompletionLatencyMs,
        peakCPUPercent: peakCPUPercent,
        memoryMB: memoryMB,
        modelName: modelName,
        prewarmed: prewarmed,
        notes: notes
    )

    metricsFile.samples.append(sample)
    try write(metricsFile, to: metricsURL)

    print("")
    print("已写入：\(metricsURL.path)")

    if arguments.evaluate {
        print("")
        fflush(stdout)
        try runEvaluator(metricsURL: metricsURL, strict: arguments.strict)
    }
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}

func parseArguments(_ rawArguments: [String]) throws -> Arguments {
    var arguments = Arguments()
    var index = 0

    while index < rawArguments.count {
        let value = rawArguments[index]
        switch value {
        case "--file":
            index += 1
            guard index < rawArguments.count else {
                throw ScriptError.invalidArguments("--file requires a path")
            }
            arguments.metricsPath = rawArguments[index]
        case "--no-evaluate":
            arguments.evaluate = false
        case "--strict":
            arguments.strict = true
            arguments.evaluate = true
        case "--help", "-h":
            arguments.help = true
        default:
            throw ScriptError.invalidArguments("unknown argument: \(value)")
        }
        index += 1
    }

    return arguments
}

func printUsage() {
    print("""
    Usage:
      scripts/record-1.0.0-asr-metrics.swift [--file <path>] [--no-evaluate] [--strict]

    Examples:
      scripts/record-1.0.0-asr-metrics.swift
      scripts/record-1.0.0-asr-metrics.swift --strict
      scripts/record-1.0.0-asr-metrics.swift --file /tmp/readytype-asr.local.json
    """)
}

func loadOrCreateMetricsFile(at url: URL) throws -> MetricsFile {
    if FileManager.default.fileExists(atPath: url.path) {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(MetricsFile.self, from: data)
    }

    let templateData = try Data(contentsOf: templateURL)
    let template = try JSONDecoder().decode(MetricsFile.self, from: templateData)
    return MetricsFile(thresholds: template.thresholds, samples: [])
}

func write(_ metricsFile: MetricsFile, to url: URL) throws {
    let directory = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(metricsFile)
    try data.write(to: url)
}

func prompt(
    _ label: String,
    defaultValue: String? = nil,
    allowedValues: [String]? = nil,
    required: Bool = false
) -> String {
    while true {
        let suffix = defaultValue.map { " [\($0)]" } ?? ""
        let allowed = allowedValues.map { " (\($0.joined(separator: "/")))" } ?? ""
        print("\(label)\(allowed)\(suffix): ", terminator: "")
        let value = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolved = value.isEmpty ? defaultValue ?? "" : value

        if required, resolved.isEmpty {
            print("这个字段必填。")
            continue
        }
        if let allowedValues, !allowedValues.contains(resolved) {
            print("请输入：\(allowedValues.joined(separator: " / "))")
            continue
        }
        return resolved
    }
}

func promptOptionalString(_ label: String, defaultValue: String? = nil) -> String? {
    let value = prompt(label, defaultValue: defaultValue)
    return value.isEmpty ? nil : value
}

func promptOptionalDouble(_ label: String) -> Double? {
    while true {
        print("\(label)（可留空）: ", terminator: "")
        let value = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty {
            return nil
        }
        if let number = Double(value) {
            return number
        }
        print("请输入数字，或留空。")
    }
}

func promptOptionalBool(_ label: String, defaultValue: Bool?) -> Bool? {
    while true {
        let suffix = defaultValue.map { $0 ? " [y]" : " [n]" } ?? ""
        print("\(label) y/n/留空\(suffix): ", terminator: "")
        let value = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if value.isEmpty {
            return defaultValue
        }
        switch value {
        case "y", "yes", "是":
            return true
        case "n", "no", "否":
            return false
        default:
            print("请输入 y、n，或留空。")
        }
    }
}

func defaultSampleID(category: String, backend: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return "\(category)-\(backend)-\(formatter.string(from: Date()))"
}

func defaultModelName(for backend: String) -> String? {
    switch backend {
    case "fast":
        return "fast-system"
    case "highAccuracy":
        return "CoreML high-accuracy package"
    default:
        return nil
    }
}

func defaultPrewarmValue(for backend: String) -> Bool? {
    switch backend {
    case "fast":
        return false
    case "highAccuracy":
        return true
    default:
        return nil
    }
}

func runEvaluator(metricsURL: URL, strict: Bool) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = strict
        ? ["swift", evaluatorURL.path, "--strict", metricsURL.path]
        : ["swift", evaluatorURL.path, metricsURL.path]

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw ScriptError.evaluatorFailed(process.terminationStatus)
    }
}

enum ScriptError: LocalizedError {
    case invalidArguments(String)
    case evaluatorFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message):
            return message
        case .evaluatorFailed(let code):
            return "ASR evaluator failed with exit code \(code)"
        }
    }
}
