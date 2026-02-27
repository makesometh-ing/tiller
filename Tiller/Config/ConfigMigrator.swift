//
//  ConfigMigrator.swift
//  Tiller
//

import Foundation

enum ConfigMigrator {

    struct MigrationResult {
        let data: Data
        let didMigrate: Bool
    }

    /// Migrates raw JSON config data from its current version to `TillerConfig.currentVersion`.
    /// Returns the (possibly updated) data and whether any migration occurred.
    static func migrate(_ data: Data) -> MigrationResult {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return MigrationResult(data: data, didMigrate: false)
        }

        let version = json["version"] as? Int ?? 0
        let target = TillerConfig.currentVersion

        if version > target {
            TillerLogger.debug("config", "[Migration] Config version \(version) is newer than app version \(target); loading as-is")
            return MigrationResult(data: data, didMigrate: false)
        }

        guard version < target else {
            return MigrationResult(data: data, didMigrate: false)
        }

        TillerLogger.debug("config", "[Migration] Migrating config from v\(version) to v\(target)")

        var current = version
        while current < target {
            json = applyMigration(from: current, json: json)
            current += 1
        }

        json["version"] = target

        guard let migrated = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return MigrationResult(data: data, didMigrate: false)
        }

        TillerLogger.debug("config", "[Migration] Migration complete: v\(version) → v\(target)")
        return MigrationResult(data: migrated, didMigrate: true)
    }

    // MARK: - Per-Version Migrations

    /// Each migration step is a pure function: (JSON dict) → (JSON dict).
    /// v0→v1: Add version field. Pre-versioning configs are otherwise compatible.
    private static func applyMigration(from version: Int, json: [String: Any]) -> [String: Any] {
        switch version {
        case 0: return migrateV0toV1(json)
        case 1: return migrateV1toV2(json)
        case 2: return migrateV2toV3(json)
        default: return json
        }
    }

    private static func migrateV0toV1(_ json: [String: Any]) -> [String: Any] {
        // v0→v1: No schema changes beyond adding the version field (handled by caller).
        return json
    }

    private static func migrateV1toV2(_ json: [String: Any]) -> [String: Any] {
        // v1→v2: Replace `containerHighlightsEnabled` with full `containerHighlights` struct.
        var result = json
        let wasEnabled = result.removeValue(forKey: "containerHighlightsEnabled") as? Bool ?? true
        let defaults = ContainerHighlightConfig.default

        result["containerHighlights"] = [
            "enabled": wasEnabled,
            "activeBorderWidth": defaults.activeBorderWidth,
            "activeBorderColor": defaults.activeBorderColor,
            "activeGlowRadius": defaults.activeGlowRadius,
            "activeGlowOpacity": defaults.activeGlowOpacity,
            "inactiveBorderWidth": defaults.inactiveBorderWidth,
            "inactiveBorderColor": defaults.inactiveBorderColor,
        ] as [String: Any]

        return result
    }

    private static func migrateV2toV3(_ json: [String: Any]) -> [String: Any] {
        // v2→v3: Add cornerRadius to containerHighlights.
        var result = json
        if var highlights = result["containerHighlights"] as? [String: Any] {
            highlights["cornerRadius"] = ContainerHighlightConfig.default.cornerRadius
            result["containerHighlights"] = highlights
        }
        return result
    }
}
