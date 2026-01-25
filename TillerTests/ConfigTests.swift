//
//  ConfigTests.swift
//  TillerTests
//

import XCTest
@testable import Tiller

@MainActor
final class ConfigTests: XCTestCase {
    private var tempDirectory: URL!
    private var mockNotificationService: MockNotificationService!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        mockNotificationService = MockNotificationService()
    }

    override func tearDown() async throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        mockNotificationService = nil
        try await super.tearDown()
    }

    private func createConfigManager() -> ConfigManager {
        return ConfigManager(
            fileManager: .default,
            basePath: tempDirectory.path,
            notificationService: mockNotificationService
        )
    }

    // MARK: - Test 1: Default Config Creation

    func testDefaultConfigCreation() async throws {
        let manager = createConfigManager()
        let result = manager.loadConfiguration()

        if case .createdDefault = result {
            let configPath = (tempDirectory.path as NSString)
                .appendingPathComponent(".config/tiller/config.json")
            XCTAssertTrue(FileManager.default.fileExists(atPath: configPath))
        } else {
            XCTFail("Expected createdDefault result, got \(result)")
        }
    }

    // MARK: - Test 2: Default Config Values

    func testDefaultConfigValues() async throws {
        let defaultConfig = TillerConfig.default

        XCTAssertEqual(defaultConfig.margin, 8)
        XCTAssertEqual(defaultConfig.padding, 8)
        XCTAssertEqual(defaultConfig.accordionOffset, 16)
        // BetterDisplay is in default floatingApps (overlay utility that can't be positioned)
        XCTAssertEqual(defaultConfig.floatingApps, ["pro.betterdisplay.BetterDisplay"])
    }

    // MARK: - Test 3: Config Directory Creation

    func testConfigDirectoryCreation() async throws {
        let manager = createConfigManager()
        _ = manager.loadConfiguration()

        let configDir = (tempDirectory.path as NSString)
            .appendingPathComponent(".config/tiller")
        XCTAssertTrue(FileManager.default.fileExists(atPath: configDir))

        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: configDir, isDirectory: &isDirectory)
        XCTAssertTrue(isDirectory.boolValue)
    }

    // MARK: - Test 4: Config Loading

    func testConfigLoading() async throws {
        let manager = createConfigManager()
        let configPath = (tempDirectory.path as NSString)
            .appendingPathComponent(".config/tiller/config.json")

        let configDir = (tempDirectory.path as NSString)
            .appendingPathComponent(".config/tiller")
        try FileManager.default.createDirectory(
            atPath: configDir,
            withIntermediateDirectories: true
        )

        let customConfig = TillerConfig(
            margin: 10,
            padding: 12,
            accordionOffset: 16,
            floatingApps: ["Safari", "Finder"]
        )
        let data = try JSONEncoder().encode(customConfig)
        try data.write(to: URL(fileURLWithPath: configPath))

        let result = manager.loadConfiguration()

        if case .loaded(let config) = result {
            XCTAssertEqual(config.margin, 10)
            XCTAssertEqual(config.padding, 12)
            XCTAssertEqual(config.accordionOffset, 16)
            XCTAssertEqual(config.floatingApps, ["Safari", "Finder"])
        } else {
            XCTFail("Expected loaded result, got \(result)")
        }
    }

    // MARK: - Test 5: Config Validation - Valid Config

    func testConfigValidation_ValidConfig() async throws {
        let validConfig = TillerConfig(
            margin: 10,
            padding: 15,
            accordionOffset: 12,
            floatingApps: []
        )

        XCTAssertTrue(ConfigValidator.isValid(validConfig))
        XCTAssertTrue(ConfigValidator.validate(validConfig).isEmpty)
    }

    // MARK: - Test 6: Config Validation - Invalid Margin

    func testConfigValidation_InvalidMargin() async throws {
        let invalidConfig = TillerConfig(
            margin: 25,
            padding: 8,
            accordionOffset: 8,
            floatingApps: []
        )

        XCTAssertFalse(ConfigValidator.isValid(invalidConfig))
        let errors = ConfigValidator.validate(invalidConfig)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors.first, .marginOutOfRange(25))
    }

    // MARK: - Test 7: Config Validation - Invalid Padding

    func testConfigValidation_InvalidPadding() async throws {
        let invalidConfig = TillerConfig(
            margin: 8,
            padding: -5,
            accordionOffset: 8,
            floatingApps: []
        )

        XCTAssertFalse(ConfigValidator.isValid(invalidConfig))
        let errors = ConfigValidator.validate(invalidConfig)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors.first, .paddingOutOfRange(-5))
    }

    // MARK: - Test 8: Config Validation - Invalid Accordion Offset

    func testConfigValidation_InvalidAccordionOffset() async throws {
        let invalidConfig = TillerConfig(
            margin: 8,
            padding: 8,
            accordionOffset: 2,
            floatingApps: []
        )

        XCTAssertFalse(ConfigValidator.isValid(invalidConfig))
        let errors = ConfigValidator.validate(invalidConfig)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors.first, .accordionOffsetOutOfRange(2))
    }

    // MARK: - Test 9: Invalid Config Fallback

    func testInvalidConfigFallback() async throws {
        let manager = createConfigManager()
        let configPath = (tempDirectory.path as NSString)
            .appendingPathComponent(".config/tiller/config.json")

        let configDir = (tempDirectory.path as NSString)
            .appendingPathComponent(".config/tiller")
        try FileManager.default.createDirectory(
            atPath: configDir,
            withIntermediateDirectories: true
        )

        let invalidConfig = TillerConfig(
            margin: 100,
            padding: 8,
            accordionOffset: 8,
            floatingApps: []
        )
        let data = try JSONEncoder().encode(invalidConfig)
        try data.write(to: URL(fileURLWithPath: configPath))

        let result = manager.loadConfiguration()

        if case .fallbackToDefault(let config, _) = result {
            XCTAssertEqual(config, TillerConfig.default)
            XCTAssertFalse(mockNotificationService.validationErrors.isEmpty)
        } else {
            XCTFail("Expected fallbackToDefault result, got \(result)")
        }
    }

    // MARK: - Test 10: Config Singleton Access

    func testConfigSingletonAccess() async throws {
        let manager = createConfigManager()
        _ = manager.loadConfiguration()

        let config1 = manager.getConfig()
        let config2 = manager.getConfig()

        XCTAssertEqual(config1, config2)
    }
}
