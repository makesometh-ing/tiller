//
//  ConfigValidation.swift
//  Tiller
//

import Foundation

nonisolated enum ConfigValidationError: Error, Equatable, Sendable {
    case marginOutOfRange(Int)
    case paddingOutOfRange(Int)
    case accordionOffsetOutOfRange(Int)
    case leaderTimeoutOutOfRange(Double)
    case duplicateKeybinding(actionID: String, conflictsWith: String)
    case invalidKeyName(actionID: String, key: String)
    case missingRequiredAction(String)
    case subLayerOnNonLeader(actionID: String)
    case highlightBorderWidthOutOfRange(String, Double)
    case highlightGlowRadiusOutOfRange(Double)
    case highlightGlowOpacityOutOfRange(Double)
    case invalidHexColor(String, String)
    case highlightCornerRadiusOutOfRange(Double)

    var description: String {
        switch self {
        case .marginOutOfRange(let value):
            return "Margin value \(value) is out of range (0-20)"
        case .paddingOutOfRange(let value):
            return "Padding value \(value) is out of range (0-20)"
        case .accordionOffsetOutOfRange(let value):
            return "Accordion offset value \(value) is out of range (4-24)"
        case .leaderTimeoutOutOfRange(let value):
            return "Leader timeout value \(value) is out of range (0-30)"
        case .duplicateKeybinding(let actionID, let conflictsWith):
            return "Duplicate keybinding: \(actionID) conflicts with \(conflictsWith)"
        case .invalidKeyName(let actionID, let key):
            return "Invalid key '\(key)' in binding for \(actionID)"
        case .missingRequiredAction(let actionID):
            return "Required action '\(actionID)' is missing from keybindings"
        case .subLayerOnNonLeader(let actionID):
            return "Action '\(actionID)' has subLayer set but leaderLayer is false"
        case .highlightBorderWidthOutOfRange(let which, let value):
            return "\(which) border width \(value) is out of range (0.5-10)"
        case .highlightGlowRadiusOutOfRange(let value):
            return "Glow radius \(value) is out of range (0-30)"
        case .highlightGlowOpacityOutOfRange(let value):
            return "Glow opacity \(value) is out of range (0-1)"
        case .invalidHexColor(let field, let value):
            return "Invalid hex color '\(value)' for \(field)"
        case .highlightCornerRadiusOutOfRange(let value):
            return "Corner radius \(value) is out of range (0-20)"
        }
    }
}

struct ConfigValidator {

    static let validModifiers: Set<String> = ["cmd", "ctrl", "option", "shift"]

    static let validKeyNames: Set<String> = {
        var keys: Set<String> = []
        for c in "abcdefghijklmnopqrstuvwxyz" { keys.insert(String(c)) }
        for c in "0123456789" { keys.insert(String(c)) }
        keys.formUnion(["space", "escape", "tab", "return", "delete", "backspace",
                        "forward_delete",
                        ",", ".", "-", "=", "/", "\\", "[", "]", ";", "'", "`"])
        for i in 1...12 { keys.insert("f\(i)") }
        return keys
    }()

    static let requiredActions: Set<String> = ["exitLeader"]

    static func validate(_ config: TillerConfig) -> [ConfigValidationError] {
        var errors: [ConfigValidationError] = []

        if !TillerConfig.ValidationRange.margin.contains(config.margin) {
            errors.append(.marginOutOfRange(config.margin))
        }
        if !TillerConfig.ValidationRange.padding.contains(config.padding) {
            errors.append(.paddingOutOfRange(config.padding))
        }
        if !TillerConfig.ValidationRange.accordionOffset.contains(config.accordionOffset) {
            errors.append(.accordionOffsetOutOfRange(config.accordionOffset))
        }
        if !TillerConfig.ValidationRange.leaderTimeout.contains(config.leaderTimeout) {
            errors.append(.leaderTimeoutOutOfRange(config.leaderTimeout))
        }

        errors.append(contentsOf: validateContainerHighlights(config.containerHighlights))
        errors.append(contentsOf: validateKeybindings(config.keybindings))
        return errors
    }

    static func isValid(_ config: TillerConfig) -> Bool {
        return validate(config).isEmpty
    }

    // MARK: - Container Highlight Validation

    static func validateContainerHighlights(_ highlights: ContainerHighlightConfig) -> [ConfigValidationError] {
        var errors: [ConfigValidationError] = []
        if !TillerConfig.ValidationRange.borderWidth.contains(highlights.activeBorderWidth) {
            errors.append(.highlightBorderWidthOutOfRange("Active", highlights.activeBorderWidth))
        }
        if !TillerConfig.ValidationRange.borderWidth.contains(highlights.inactiveBorderWidth) {
            errors.append(.highlightBorderWidthOutOfRange("Inactive", highlights.inactiveBorderWidth))
        }
        if !TillerConfig.ValidationRange.glowRadius.contains(highlights.activeGlowRadius) {
            errors.append(.highlightGlowRadiusOutOfRange(highlights.activeGlowRadius))
        }
        if !TillerConfig.ValidationRange.glowOpacity.contains(highlights.activeGlowOpacity) {
            errors.append(.highlightGlowOpacityOutOfRange(highlights.activeGlowOpacity))
        }
        if !isValidHexColor(highlights.activeBorderColor) {
            errors.append(.invalidHexColor("activeBorderColor", highlights.activeBorderColor))
        }
        if !isValidHexColor(highlights.inactiveBorderColor) {
            errors.append(.invalidHexColor("inactiveBorderColor", highlights.inactiveBorderColor))
        }
        if !TillerConfig.ValidationRange.cornerRadius.contains(highlights.cornerRadius) {
            errors.append(.highlightCornerRadiusOutOfRange(highlights.cornerRadius))
        }
        return errors
    }

    private static func isValidHexColor(_ hex: String) -> Bool {
        var str = hex
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6 || str.count == 8 else { return false }
        return str.allSatisfy { $0.isHexDigit }
    }

    // MARK: - Keybinding Validation

    static func validateKeybindings(_ keybindings: KeybindingsConfig) -> [ConfigValidationError] {
        var errors: [ConfigValidationError] = []

        validateKeys(keybindings.leaderTrigger, actionID: "leaderTrigger", errors: &errors)

        for required in requiredActions {
            if keybindings.actions[required] == nil {
                errors.append(.missingRequiredAction(required))
            }
        }

        var seen: [String: String] = [:] // "layer:keys" → actionID

        for (actionID, binding) in keybindings.actions {
            validateKeys(binding.keys, actionID: actionID, errors: &errors)

            if !binding.leaderLayer && binding.subLayer != nil {
                errors.append(.subLayerOnNonLeader(actionID: actionID))
            }

            let layer = binding.leaderLayer ? (binding.subLayer ?? "root") : "global"
            let signature = "\(layer):\(binding.keys.joined(separator: "+"))"
            if let existing = seen[signature] {
                errors.append(.duplicateKeybinding(actionID: actionID, conflictsWith: existing))
            } else {
                seen[signature] = actionID
            }
        }

        return errors
    }

    private static func validateKeys(_ keys: [String], actionID: String, errors: inout [ConfigValidationError]) {
        guard let keyName = keys.last else { return }
        let modifiers = keys.dropLast()

        if !validKeyNames.contains(keyName) {
            errors.append(.invalidKeyName(actionID: actionID, key: keyName))
        }
        for modifier in modifiers where !validModifiers.contains(modifier) {
            errors.append(.invalidKeyName(actionID: actionID, key: modifier))
        }
    }
}
