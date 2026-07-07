import Foundation

func currentAppLocale() -> Locale {
    let selectedLanguageCode = UserDefaults.standard.string(forKey: LocalizationConstants.languageStorageKey)
        ?? LocalizationConstants.defaultLanguageCode
    return currentAppLocale(languageCode: selectedLanguageCode)
}

func currentAppLocale(languageCode: String) -> Locale {
    switch languageCode {
    case "de":
        return Locale(identifier: "de_DE")
    case "fr":
        return Locale(identifier: "fr_FR")
    default:
        return Locale(identifier: "en_US")
    }
}

func localizedAppString(_ key: String) -> String {
    let languageCode = UserDefaults.standard.string(forKey: LocalizationConstants.languageStorageKey)
        ?? LocalizationConstants.defaultLanguageCode

    return localizedAppString(key, languageCode: languageCode)
}

func localizedAppString(_ key: String, languageCode: String) -> String {
    guard
        let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
        let bundle = Bundle(path: path)
    else {
        return NSLocalizedString(key, comment: "")
    }

    return NSLocalizedString(key, bundle: bundle, comment: "")
}

func prewarmWelcomeLocalizations() {
    let welcomeKeys = [
        "Language",
        "Changes the app language for onboarding.",
        "Switch language to English",
        "Switch language to German",
        "Switch language to French",
        "Welcome to CARWatch!",
        "CARWatch is intended for study participants. It helps you follow your study schedule by sending reminders, and confirming samples by barcode scans.",
        "Use this app only if you were invited to take part in a study.",
        "You will receive reminders for scheduled saliva samples.",
        "You need a study QR code to set up the app.",
        "Continue",
        "Opens the study participation information.",
        "Open app information",
        "Shows study and developer information."
    ]

    DispatchQueue.global(qos: .utility).async {
        for languageCode in LocalizationConstants.supportedLanguageCodes {
            _ = currentAppLocale(languageCode: languageCode)
            for key in welcomeKeys {
                _ = localizedAppString(key, languageCode: languageCode)
            }
        }
    }
}

func getDayHourMinuteSecondFromTime(time: Date) -> (Int, Int, Int, Int) {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: time)
    let minute = calendar.component(.minute, from: time)
    let second = calendar.component(.second, from: time)
    let day = calendar.component(.day, from: time)
    return (day, hour, minute, second)
}

func getHourMinFormattedString(time: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = currentAppLocale()
    dateFormatter.dateFormat = dateFormatter.locale.identifier.hasPrefix("de") ? "HH:mm" : "h:mm a"
    return dateFormatter.string(from: time)
}

func getDateTomorrowMorning() -> Date {
    /// returns a date object referring to 8am the next day from now
    /// defaults to current date and time if construction fails
    let calendar = Calendar.current
    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) {
        var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        
        tomorrowComponents.hour = 8
        tomorrowComponents.minute = 0
        
        if let tomorrowMorning = calendar.date(from: tomorrowComponents) {
            return tomorrowMorning
        }
    }
    print("getDateTomorrowMorning failed")
    return Date()
}

func getUnixTimeMillisFromDate(_ date: Date) -> Int {
    /// returns the time since 1st January 1970 in milliseconds from a date
    return Int(date.timeIntervalSince1970 * 1000)
}

func formatDateForLogs(_ date: Date) -> String {
    /// returns human readable format of date for app logs
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "EE MMM dd yyyy HH:mm:ss ZZZZ"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    return dateFormatter.string(from: date)
}

struct Time: Codable {
    var hour: Int
    var minute: Int
    
    func stringValue() -> String {
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let calendar = Calendar.current
        guard let date = calendar.date(from: dateComponents) else {
            return "\(String(format: "%02d", hour)):\(String(format: "%02d", minute))"
        }

        return getHourMinFormattedString(time: date)
    }
}
