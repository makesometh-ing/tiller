//
//  ConfigValidation.swift
//  Tiller
//

import Foundation

enum ConfigValidationError: Error, Equatable, Sendable {
    case marginOutOfRange(Int)
    case paddingOutOfRange(Int)
    case accordionOffsetOutOfRange(Int)

    var description: String {
        switch self {
        case .marginOutOfRange(let value):
            return "Margin value \(value) is out of range (0-20)"
        case .paddingOutOfRange(let value):
            return "Padding value \(value) is out of range (0-20)"
        case .accordionOffsetOutOfRange(let value):
            return "Accordion offset value \(value) is out of range (4-24)"
        }
    }
}

struct ConfigValidator {
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

        return errors
    }

    static func isValid(_ config: TillerConfig) -> Bool {
        return validate(config).isEmpty
    }
}
