//
//  ConfigManager.swift
//  Tiller
//

import Foundation

enum ConfigLoadResult: Equatable, Sendable {
    case loaded(TillerConfig)
    case createdDefault(TillerConfig)
    case fallbackToDefault(TillerConfig, reason: String)

    var config: TillerConfig {
        switch self {
        case .loaded(let config),
             .createdDefault(let config),
             .fallbackToDefault(let config, _):
            return config
        }
    }
}

@MainActor
final class ConfigManager {
    static let shared = ConfigManager()

    private let fileManager: FileManager
    private let basePath: String
    private let notificationService: NotificationServiceProtocol

    private var _config: TillerConfig = .default
    private(set) var hasConfigError: Bool = false
    private(set) var configErrorMessage: String?

    var onConfigReloaded: ((TillerConfig) -> Void)?

    var configDirectoryPath: String {
        return (basePath as NSString).appendingPathComponent(".config/tiller")
    }

    var configFilePath: String {
        return (configDirectoryPath as NSString).appendingPathComponent("config.json")
    }

    private init() {
        self.fileManager = .default
        self.basePath = NSHomeDirectory()
        self.notificationService = SystemNotificationService()
    }

    init(fileManager: FileManager, basePath: String, notificationService: NotificationServiceProtocol) {
        self.fileManager = fileManager
        self.basePath = basePath
        self.notificationService = notificationService
    }

    // MARK: - Load

    @discardableResult
    func loadConfiguration() -> ConfigLoadResult {
        if !fileManager.fileExists(atPath: configDirectoryPath) {
            do {
                try fileManager.createDirectory(
                    atPath: configDirectoryPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                notificationService.showConfigParseError(error)
                _config = .default
                setError("Failed to create config directory: \(error.localizedDescription)")
                return .fallbackToDefault(.default, reason: configErrorMessage!)
            }
        }

        if !fileManager.fileExists(atPath: configFilePath) {
            let result = writeDefaultConfig()
            if case .fallbackToDefault = result {
                return result
            }
            clearError()
            return .createdDefault(.default)
        }

        let result = loadExistingConfig()
        if case .fallbackToDefault = result {
            // error already set inside loadExistingConfig
        } else {
            clearError()
        }
        return result
    }

    // MARK: - Reload

    @discardableResult
    func reloadConfiguration() -> ConfigLoadResult {
        let result = loadExistingConfig()
        switch result {
        case .loaded(let config):
            clearError()
            onConfigReloaded?(config)
        case .fallbackToDefault:
            // error already set inside loadExistingConfig
            break
        case .createdDefault:
            clearError()
        }
        return result
    }

    // MARK: - Reset

    @discardableResult
    func resetToDefaults() -> ConfigLoadResult {
        let result = writeDefaultConfig()
        clearError()
        onConfigReloaded?(.default)
        return result
    }

    // MARK: - Read

    func getConfig() -> TillerConfig {
        return _config
    }

    // MARK: - Private

    private func writeDefaultConfig() -> ConfigLoadResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(TillerConfig.default)
            try data.write(to: URL(fileURLWithPath: configFilePath))
            _config = .default
            return .createdDefault(.default)
        } catch {
            notificationService.showConfigParseError(error)
            _config = .default
            return .fallbackToDefault(.default, reason: "Failed to write default config: \(error.localizedDescription)")
        }
    }

    private func loadExistingConfig() -> ConfigLoadResult {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: configFilePath))
        } catch {
            notificationService.showConfigParseError(error)
            _config = .default
            setError("Cannot read config file: \(error.localizedDescription)")
            return .fallbackToDefault(.default, reason: configErrorMessage!)
        }

        do {
            let config = try JSONDecoder().decode(TillerConfig.self, from: data)

            let validationErrors = ConfigValidator.validate(config)
            if !validationErrors.isEmpty {
                for error in validationErrors {
                    notificationService.showConfigValidationError(error)
                }
                _config = .default
                setError(validationErrors.first!.description)
                return .fallbackToDefault(.default, reason: configErrorMessage!)
            }

            _config = config
            return .loaded(config)
        } catch {
            notificationService.showConfigParseError(error)
            _config = .default
            setError(Self.humanReadableParseError(error, jsonData: data))
            return .fallbackToDefault(.default, reason: configErrorMessage!)
        }
    }

    private func setError(_ message: String) {
        hasConfigError = true
        configErrorMessage = message
    }

    private func clearError() {
        hasConfigError = false
        configErrorMessage = nil
    }

    // MARK: - Error Formatting

    static func humanReadableParseError(_ error: Error, jsonData: Data) -> String {
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .dataCorrupted(let ctx):
                if let offset = (ctx.underlyingError as NSError?)?.userInfo["NSJSONSerializationErrorIndex"] as? Int {
                    let line = lineNumber(in: jsonData, at: offset)
                    return "Parse error on line \(line): \(ctx.debugDescription)"
                }
                return "Parse error: \(ctx.debugDescription)"
            case .keyNotFound(let key, _):
                return "Missing required key '\(key.stringValue)'"
            case .typeMismatch(let type, let ctx):
                let path = ctx.codingPath.map(\.stringValue).joined(separator: ".")
                return "Type mismatch at \(path): expected \(type)"
            case .valueNotFound(let type, let ctx):
                let path = ctx.codingPath.map(\.stringValue).joined(separator: ".")
                return "Missing value at \(path): expected \(type)"
            @unknown default:
                break
            }
        }
        return "Failed to parse config: \(error.localizedDescription)"
    }

    static func lineNumber(in data: Data, at byteOffset: Int) -> Int {
        let slice = data.prefix(min(byteOffset, data.count))
        return slice.reduce(1) { count, byte in byte == UInt8(ascii: "\n") ? count + 1 : count }
    }
}
