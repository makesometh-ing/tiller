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
                return .fallbackToDefault(.default, reason: "Failed to create config directory: \(error.localizedDescription)")
            }
        }

        if !fileManager.fileExists(atPath: configFilePath) {
            let result = writeDefaultConfig()
            if case .fallbackToDefault = result {
                return result
            }
            return .createdDefault(.default)
        }

        return loadExistingConfig()
    }

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
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configFilePath))
            let config = try JSONDecoder().decode(TillerConfig.self, from: data)

            let validationErrors = ConfigValidator.validate(config)
            if !validationErrors.isEmpty {
                for error in validationErrors {
                    notificationService.showConfigValidationError(error)
                }
                _config = .default
                return .fallbackToDefault(.default, reason: "Config validation failed")
            }

            _config = config
            return .loaded(config)
        } catch {
            notificationService.showConfigParseError(error)
            _config = .default
            return .fallbackToDefault(.default, reason: "Failed to parse config: \(error.localizedDescription)")
        }
    }

    func getConfig() -> TillerConfig {
        return _config
    }
}
