import Combine
import Foundation
import SwiftUI

enum ResolvedLanguage: String, Sendable {
    case english = "en"
    case chinese = "zh"
}

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    enum Preference: String, CaseIterable, Identifiable, Sendable {
        case system
        case english
        case chinese

        var id: String { rawValue }

        func displayName(language: ResolvedLanguage) -> String {
            switch self {
            case .system:
                return L10n.string(.languageSystem, language: language)
            case .english:
                return L10n.string(.languageEnglish, language: language)
            case .chinese:
                return L10n.string(.languageChinese, language: language)
            }
        }
    }

    @Published var preference: Preference {
        didSet {
            UserDefaults.standard.set(preference.rawValue, forKey: Self.preferenceKey)
        }
    }

    var resolved: ResolvedLanguage {
        switch preference {
        case .system:
            let identifier = Locale.preferredLanguages.first ?? "en"
            return identifier.hasPrefix("zh") ? .chinese : .english
        case .english:
            return .english
        case .chinese:
            return .chinese
        }
    }

    private static let preferenceKey = "appLanguagePreference"

    nonisolated static func resolvedLanguage() -> ResolvedLanguage {
        let raw = UserDefaults.standard.string(forKey: "appLanguagePreference") ?? Preference.system.rawValue
        let pref = Preference(rawValue: raw) ?? .system
        switch pref {
        case .system:
            let identifier = Locale.preferredLanguages.first ?? "en"
            return identifier.hasPrefix("zh") ? .chinese : .english
        case .english:
            return .english
        case .chinese:
            return .chinese
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.preferenceKey),
           let saved = Preference(rawValue: raw) {
            preference = saved
        } else {
            preference = .system
        }
    }

    func t(_ key: L10n.Key) -> String {
        L10n.string(key, language: resolved)
    }

    func format(_ key: L10n.Key, _ arguments: CVarArg...) -> String {
        let template = t(key)
        return String(format: template, locale: resolved.locale, arguments: arguments)
    }
}

extension ResolvedLanguage {
    var locale: Locale {
        switch self {
        case .english:
            return Locale(identifier: "en_US")
        case .chinese:
            return Locale(identifier: "zh_CN")
        }
    }
}
