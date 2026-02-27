//
//  ConfigTests.swift
//  TillerTests
//

import Testing
import Foundation
@testable import Tiller

struct ConfigTests {
    let tempDirectory: URL
    let mockNotificationService: MockNotificationService

    init() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        mockNotificationService = MockNotificationService()
    }

    private func createConfigManager() -> ConfigManager {
        return ConfigManager(
            fileManager: .default,
            basePath: tempDirectory.path,
            notificationService: mockNotificationService
        )
    }

    // MARK: - Test 1: Default Config Creation

    @Test func defaultConfigCreation() async throws {
        let manager = createConfigManager()
        let result = manager.loadConfiguration()

        if case .createdDefault = result {
            let configPath = (tempDirectory.path as NSString)
                .appendingPathComponent(".config/tiller/config.json")
            #expect(FileManager.default.fileExists(atPath: configPath))
        } else {
            Issue.record("Expected createdDefault result, got \(result)")
        }
    }

    // MARK: - Test 2: Default Config Values

    @Test func defaultConfigValues() async throws {
        let defaultConfig = TillerConfig.default

        #expect(defaultConfig.margin == 8)
        #expect(defaultConfig.padding == 8)
        #expect(defaultConfig.accordionOffset == 16)
        // BetterDisplay is in default floatingApps (overlay utility that can't be positioned)
        #expect(defaultConfig.floatingApps == ["pro.betterdisplay.BetterDisplay"])
    }

    // MARK: - Test 3: Config Directory Creation

    @Test func configDirectoryCreation() async throws {
        let manager = createConfigManager()
        _ = manager.loadConfiguration()

        let configDir = (tempDirectory.path as NSString)
            .appendingPathComponent(".config/tiller")
        #expect(FileManager.default.fileExists(atPath: configDir))

        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: configDir, isDirectory: &isDirectory)
        #expect(isDirectory.boolValue)
    }

    // MARK: - Test 4: Config Loading

    @Test func configLoading() async throws {
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
            #expect(config.margin == 10)
            #expect(config.padding == 12)
            #expect(config.accordionOffset == 16)
            #expect(config.floatingApps == ["Safari", "Finder"])
        } else {
            Issue.record("Expected loaded result, got \(result)")
        }
    }

    // MARK: - Test 5: Config Validation - Valid Config

    @Test func configValidation_ValidConfig() async throws {
        let validConfig = TillerConfig(
            margin: 10,
            padding: 15,
            accordionOffset: 12,
            floatingApps: []
        )

        #expect(ConfigValidator.isValid(validConfig))
        #expect(ConfigValidator.validate(validConfig).isEmpty)
    }

    // MARK: - Test 6: Config Validation - Invalid Margin

    @Test func configValidation_InvalidMargin() async throws {
        let invalidConfig = TillerConfig(
            margin: 25,
            padding: 8,
            accordionOffset: 8,
            floatingApps: []
        )

        #expect(!ConfigValidator.isValid(invalidConfig))
        let errors = ConfigValidator.validate(invalidConfig)
        #expect(errors.count == 1)
        #expect(errors.first == .marginOutOfRange(25))
    }

    // MARK: - Test 7: Config Validation - Invalid Padding

    @Test func configValidation_InvalidPadding() async throws {
        let invalidConfig = TillerConfig(
            margin: 8,
            padding: -5,
            accordionOffset: 8,
            floatingApps: []
        )

        #expect(!ConfigValidator.isValid(invalidConfig))
        let errors = ConfigValidator.validate(invalidConfig)
        #expect(errors.count == 1)
        #expect(errors.first == .paddingOutOfRange(-5))
    }

    // MARK: - Test 8: Config Validation - Invalid Accordion Offset

    @Test func configValidation_InvalidAccordionOffset() async throws {
        let invalidConfig = TillerConfig(
            margin: 8,
            padding: 8,
            accordionOffset: 2,
            floatingApps: []
        )

        #expect(!ConfigValidator.isValid(invalidConfig))
        let errors = ConfigValidator.validate(invalidConfig)
        #expect(errors.count == 1)
        #expect(errors.first == .accordionOffsetOutOfRange(2))
    }

    // MARK: - Test 9: Invalid Config Fallback

    @Test func invalidConfigFallback() async throws {
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
            #expect(config == TillerConfig.default)
            #expect(!mockNotificationService.validationErrors.isEmpty)
        } else {
            Issue.record("Expected fallbackToDefault result, got \(result)")
        }
    }

    // MARK: - Test 10: Config Singleton Access

    @Test func configSingletonAccess() async throws {
        let manager = createConfigManager()
        _ = manager.loadConfiguration()

        let config1 = manager.getConfig()
        let config2 = manager.getConfig()

        #expect(config1 == config2)
    }

    // MARK: - Keybinding Decoding

    @Test func decodeConfigWithKeybindings() throws {
        let json = """
        {
            "margin": 8, "padding": 8, "accordionOffset": 16,
            "floatingApps": [],
            "keybindings": {
                "leaderTrigger": ["option", "space"],
                "actions": {
                    "exitLeader": { "keys": ["escape"], "leaderLayer": true, "subLayer": null, "staysInLeader": false },
                    "moveWindow.left": { "keys": ["j"], "leaderLayer": true, "subLayer": null, "staysInLeader": true }
                }
            }
        }
        """
        let config = try JSONDecoder().decode(TillerConfig.self, from: Data(json.utf8))

        #expect(config.keybindings.leaderTrigger == ["option", "space"])
        #expect(config.keybindings.actions.count == 2)
        #expect(config.keybindings.actions["moveWindow.left"]?.keys == ["j"])
    }

    @Test func decodeConfigWithoutKeybindingsGetsDefaults() throws {
        let json = """
        { "margin": 8, "padding": 8, "accordionOffset": 16, "floatingApps": [] }
        """
        let config = try JSONDecoder().decode(TillerConfig.self, from: Data(json.utf8))

        #expect(config.keybindings == KeybindingsConfig.default)
    }

    @Test func defaultConfigIncludesKeybindings() {
        #expect(TillerConfig.default.keybindings == KeybindingsConfig.default)
        #expect(TillerConfig.default.keybindings.actions.count == 9)
        #expect(TillerConfig.default.keybindings.actions["exitLeader"] != nil)
    }

    // MARK: - Keybinding Validation

    @Test func validationDuplicateKeybinding() {
        var config = TillerConfig.default
        var kb = KeybindingsConfig.default
        kb.actions["moveWindow.left"] = ActionBinding(keys: ["h"], leaderLayer: true, subLayer: nil, staysInLeader: true)
        kb.actions["focusContainer.left"] = ActionBinding(keys: ["h"], leaderLayer: true, subLayer: nil, staysInLeader: true)
        config.keybindings = kb

        let errors = ConfigValidator.validate(config)
        let dupes = errors.filter {
            if case .duplicateKeybinding = $0 { return true }
            return false
        }
        #expect(!dupes.isEmpty, "Should detect duplicate keybinding")
    }

    @Test func validationInvalidKeyName() {
        var config = TillerConfig.default
        var kb = KeybindingsConfig.default
        kb.actions["moveWindow.left"] = ActionBinding(keys: ["INVALID_KEY"], leaderLayer: true, subLayer: nil, staysInLeader: true)
        config.keybindings = kb

        let errors = ConfigValidator.validate(config)
        let invalidKeys = errors.filter {
            if case .invalidKeyName = $0 { return true }
            return false
        }
        #expect(!invalidKeys.isEmpty, "Should detect invalid key name")
    }

    @Test func validationMissingExitLeader() {
        var config = TillerConfig.default
        var kb = KeybindingsConfig.default
        kb.actions.removeValue(forKey: "exitLeader")
        config.keybindings = kb

        let errors = ConfigValidator.validate(config)
        let missing = errors.filter {
            if case .missingRequiredAction = $0 { return true }
            return false
        }
        #expect(!missing.isEmpty, "Should require exitLeader action")
    }

    @Test func validationSubLayerOnNonLeader() {
        var config = TillerConfig.default
        var kb = KeybindingsConfig.default
        kb.actions["moveWindow.left"] = ActionBinding(keys: ["h"], leaderLayer: false, subLayer: "m", staysInLeader: false)
        config.keybindings = kb

        let errors = ConfigValidator.validate(config)
        let subLayerErrors = errors.filter {
            if case .subLayerOnNonLeader = $0 { return true }
            return false
        }
        #expect(!subLayerErrors.isEmpty, "Should reject subLayer when leaderLayer is false")
    }

    @Test func validationDefaultConfigIsValid() {
        #expect(ConfigValidator.isValid(.default))
    }

    // MARK: - Reload

    @Test func reloadValidConfig() async throws {
        let manager = createConfigManager()
        manager.loadConfiguration()

        // Write a modified valid config
        let customConfig = TillerConfig(margin: 10, padding: 10, accordionOffset: 16, floatingApps: [])
        let data = try JSONEncoder().encode(customConfig)
        try data.write(to: URL(fileURLWithPath: manager.configFilePath))

        let result = manager.reloadConfiguration()

        if case .loaded(let config) = result {
            #expect(config.margin == 10)
            #expect(!manager.hasConfigError)
            #expect(manager.configErrorMessage == nil)
        } else {
            Issue.record("Expected loaded result, got \(result)")
        }
    }

    @Test func reloadInvalidConfigFallsBack() async throws {
        let manager = createConfigManager()
        manager.loadConfiguration()

        // Write an invalid config
        let invalidConfig = TillerConfig(margin: 999, padding: 8, accordionOffset: 16, floatingApps: [])
        let data = try JSONEncoder().encode(invalidConfig)
        try data.write(to: URL(fileURLWithPath: manager.configFilePath))

        let result = manager.reloadConfiguration()

        if case .fallbackToDefault = result {
            #expect(manager.hasConfigError)
            #expect(manager.configErrorMessage != nil)
            #expect(manager.getConfig() == TillerConfig.default)
        } else {
            Issue.record("Expected fallbackToDefault result, got \(result)")
        }
    }

    @Test func reloadCallsOnConfigReloaded() async throws {
        let manager = createConfigManager()
        manager.loadConfiguration()

        var reloadedConfig: TillerConfig?
        manager.onConfigReloaded = { config in
            reloadedConfig = config
        }

        let customConfig = TillerConfig(margin: 5, padding: 5, accordionOffset: 8, floatingApps: [])
        let data = try JSONEncoder().encode(customConfig)
        try data.write(to: URL(fileURLWithPath: manager.configFilePath))

        manager.reloadConfiguration()

        #expect(reloadedConfig != nil)
        #expect(reloadedConfig?.margin == 5)
    }

    // MARK: - Reset to Defaults

    @Test func resetToDefaultsClearsError() async throws {
        let manager = createConfigManager()
        manager.loadConfiguration()

        // Write invalid config and reload to set error
        let invalidConfig = TillerConfig(margin: 999, padding: 8, accordionOffset: 16, floatingApps: [])
        let data = try JSONEncoder().encode(invalidConfig)
        try data.write(to: URL(fileURLWithPath: manager.configFilePath))
        manager.reloadConfiguration()
        #expect(manager.hasConfigError)

        // Reset
        manager.resetToDefaults()

        #expect(!manager.hasConfigError)
        #expect(manager.configErrorMessage == nil)
        #expect(manager.getConfig() == TillerConfig.default)
    }

    // MARK: - Error Message Formatting

    @Test func lineNumberCalculation() {
        let json = "{\n  \"margin\": 8,\n  \"bad\": !\n}"
        let data = Data(json.utf8)

        // Offset of '!' is at line 3
        let offset = json.distance(from: json.startIndex, to: json.range(of: "!")!.lowerBound)
        #expect(ConfigManager.lineNumber(in: data, at: offset) == 3)
    }

    // MARK: - Version Migration

    @Test func migrationAddsVersionToPreVersioningConfig() {
        let json = """
        { "margin": 8, "padding": 8, "accordionOffset": 16, "floatingApps": [] }
        """
        let result = ConfigMigrator.migrate(Data(json.utf8))

        #expect(result.didMigrate)

        let migrated = try! JSONSerialization.jsonObject(with: result.data) as! [String: Any]
        #expect(migrated["version"] as? Int == TillerConfig.currentVersion)
    }

    @Test func migrationPreservesUserValues() {
        let json = """
        { "margin": 12, "padding": 14, "accordionOffset": 20, "leaderTimeout": 10, "floatingApps": ["com.test.app"] }
        """
        let result = ConfigMigrator.migrate(Data(json.utf8))

        let config = try! JSONDecoder().decode(TillerConfig.self, from: result.data)
        #expect(config.margin == 12)
        #expect(config.padding == 14)
        #expect(config.accordionOffset == 20)
        #expect(config.leaderTimeout == 10)
        #expect(config.floatingApps == ["com.test.app"])
    }

    @Test func migrationNoOpOnCurrentVersion() {
        let json = """
        { "version": \(TillerConfig.currentVersion), "margin": 8, "padding": 8, "accordionOffset": 16, "floatingApps": [] }
        """
        let result = ConfigMigrator.migrate(Data(json.utf8))
        #expect(!result.didMigrate)
    }

    @Test func migrationNoOpOnNewerVersion() {
        let json = """
        { "version": 99, "margin": 8, "padding": 8, "accordionOffset": 16, "floatingApps": [] }
        """
        let result = ConfigMigrator.migrate(Data(json.utf8))
        #expect(!result.didMigrate)
    }

    @Test func migrationHandlesInvalidJSON() {
        let data = Data("not json".utf8)
        let result = ConfigMigrator.migrate(data)
        #expect(!result.didMigrate)
        #expect(result.data == data)
    }

    @Test func configDecodesVersionField() throws {
        let json = """
        { "version": \(TillerConfig.currentVersion), "margin": 8, "padding": 8, "accordionOffset": 16, "floatingApps": [] }
        """
        let config = try JSONDecoder().decode(TillerConfig.self, from: Data(json.utf8))
        #expect(config.version == TillerConfig.currentVersion)
    }

    @Test func configMissingVersionDefaultsToZero() throws {
        let json = """
        { "margin": 8, "padding": 8, "accordionOffset": 16, "floatingApps": [] }
        """
        let config = try JSONDecoder().decode(TillerConfig.self, from: Data(json.utf8))
        #expect(config.version == 0)
    }

    @Test func defaultConfigHasCurrentVersion() {
        #expect(TillerConfig.default.version == TillerConfig.currentVersion)
    }

    // MARK: - V1->V2 Migration (containerHighlightsEnabled -> containerHighlights)

    @Test func migrationV1ToV2MovesContainerHighlightsEnabled() {
        let json = """
        { "version": 1, "margin": 8, "padding": 8, "accordionOffset": 16, "floatingApps": [], "containerHighlightsEnabled": false }
        """
        let result = ConfigMigrator.migrate(Data(json.utf8))
        #expect(result.didMigrate)

        let config = try! JSONDecoder().decode(TillerConfig.self, from: result.data)
        #expect(config.version == TillerConfig.currentVersion)
        #expect(!config.containerHighlights.enabled)
    }

    @Test func migrationV1ToV2DefaultsHighlightsWhenFieldMissing() {
        let json = """
        { "version": 1, "margin": 8, "padding": 8, "accordionOffset": 16, "floatingApps": [] }
        """
        let result = ConfigMigrator.migrate(Data(json.utf8))
        #expect(result.didMigrate)

        let config = try! JSONDecoder().decode(TillerConfig.self, from: result.data)
        #expect(config.containerHighlights.enabled) // default is true
    }

    @Test func containerHighlightConfigDecoding() throws {
        let json = """
        {
            "version": 3, "margin": 8, "padding": 8, "accordionOffset": 16, "floatingApps": [],
            "containerHighlights": {
                "enabled": true,
                "activeBorderWidth": 3,
                "activeBorderColor": "#FF0000",
                "activeGlowRadius": 12,
                "activeGlowOpacity": 0.8,
                "inactiveBorderWidth": 2,
                "inactiveBorderColor": "#FFFFFF80",
                "cornerRadius": 10
            }
        }
        """
        let config = try JSONDecoder().decode(TillerConfig.self, from: Data(json.utf8))
        #expect(config.containerHighlights.activeBorderWidth == 3)
        #expect(config.containerHighlights.activeBorderColor == "#FF0000")
        #expect(config.containerHighlights.activeGlowRadius == 12)
        #expect(config.containerHighlights.activeGlowOpacity == 0.8)
        #expect(config.containerHighlights.inactiveBorderWidth == 2)
        #expect(config.containerHighlights.inactiveBorderColor == "#FFFFFF80")
        #expect(config.containerHighlights.cornerRadius == 10)
    }

    @Test func containerHighlightConfigDefaultsWhenMissing() throws {
        let json = """
        { "version": 3, "margin": 8, "padding": 8, "accordionOffset": 16, "floatingApps": [] }
        """
        let config = try JSONDecoder().decode(TillerConfig.self, from: Data(json.utf8))
        #expect(config.containerHighlights == ContainerHighlightConfig.default)
    }

    @Test func containerHighlightValidationRejectsInvalidBorderWidth() {
        var config = TillerConfig.default
        config.containerHighlights.activeBorderWidth = 50
        let errors = ConfigValidator.validate(config)
        #expect(errors.contains(where: {
            if case .highlightBorderWidthOutOfRange("Active", 50) = $0 { return true }
            return false
        }))
    }

    @Test func containerHighlightValidationRejectsInvalidHexColor() {
        var config = TillerConfig.default
        config.containerHighlights.activeBorderColor = "not-a-color"
        let errors = ConfigValidator.validate(config)
        #expect(errors.contains(where: {
            if case .invalidHexColor("activeBorderColor", _) = $0 { return true }
            return false
        }))
    }

    // MARK: - V2->V3 Migration (add cornerRadius)

    @Test func migrationV2ToV3AddsCornerRadius() {
        let json = """
        {
            "version": 2, "margin": 8, "padding": 8, "accordionOffset": 16, "floatingApps": [],
            "containerHighlights": {
                "enabled": true, "activeBorderWidth": 2, "activeBorderColor": "#007AFF",
                "activeGlowRadius": 8, "activeGlowOpacity": 0.6,
                "inactiveBorderWidth": 1, "inactiveBorderColor": "#FFFFFF66"
            }
        }
        """
        let result = ConfigMigrator.migrate(Data(json.utf8))
        #expect(result.didMigrate)

        let config = try! JSONDecoder().decode(TillerConfig.self, from: result.data)
        #expect(config.version == TillerConfig.currentVersion)
        #expect(config.containerHighlights.cornerRadius == 8)
    }

    @Test func cornerRadiusDefaultsWhenMissing() throws {
        let json = """
        {
            "version": 3, "margin": 8, "padding": 8, "accordionOffset": 16, "floatingApps": [],
            "containerHighlights": { "enabled": true }
        }
        """
        let config = try JSONDecoder().decode(TillerConfig.self, from: Data(json.utf8))
        #expect(config.containerHighlights.cornerRadius == 8)
    }

    @Test func cornerRadiusDecodesCustomValue() throws {
        let json = """
        {
            "version": 3, "margin": 8, "padding": 8, "accordionOffset": 16, "floatingApps": [],
            "containerHighlights": { "cornerRadius": 12 }
        }
        """
        let config = try JSONDecoder().decode(TillerConfig.self, from: Data(json.utf8))
        #expect(config.containerHighlights.cornerRadius == 12)
    }

    @Test func cornerRadiusValidationRejectsOutOfRange() {
        var config = TillerConfig.default
        config.containerHighlights.cornerRadius = 25
        let errors = ConfigValidator.validate(config)
        #expect(errors.contains(where: {
            if case .highlightCornerRadiusOutOfRange(25) = $0 { return true }
            return false
        }))
    }

    @Test func migrationWritesBackToDisk() async throws {
        let manager = createConfigManager()

        // Write a pre-versioning config
        let configDir = (tempDirectory.path as NSString).appendingPathComponent(".config/tiller")
        try FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)

        let json = """
        { "margin": 8, "padding": 8, "accordionOffset": 16, "floatingApps": [] }
        """
        try Data(json.utf8).write(to: URL(fileURLWithPath: manager.configFilePath))

        // Load triggers migration
        let result = manager.loadConfiguration()
        if case .loaded(let config) = result {
            #expect(config.version == TillerConfig.currentVersion)
        } else {
            Issue.record("Expected loaded result, got \(result)")
        }

        // Verify the file on disk was updated with version
        let diskData = try Data(contentsOf: URL(fileURLWithPath: manager.configFilePath))
        let diskJSON = try JSONSerialization.jsonObject(with: diskData) as! [String: Any]
        #expect(diskJSON["version"] as? Int == TillerConfig.currentVersion)
    }
}
