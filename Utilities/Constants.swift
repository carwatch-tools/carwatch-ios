import SwiftUI

struct PermissionConstants {
    enum PermissionType {
        case notifications, camera
    }
    
    static let appSettingsUrl = URL(string: UIApplication.openSettingsURLString)
}

struct NotificationConstants {
    static let numberOfSubsequentNotifications = 2
    static let minutesBetweenNotifications = 1
    enum ToastType {
        case feedbackToast, wakeupReportedToast, studyFinishedToast
    }
}

struct AlarmConstants {
    static let initialAlarmId = "initial"
    static let timedAlarmId = "timed"
}

struct ScannerConstants {
    enum CodeType {
        case ean8, qr
    }
    enum AlertType {
        case success, invalid
    }
    static let overlayWidthFactor: CGFloat = 1.5
    static let barcodeWidthHeightRatio: CGFloat = 2
    static let defaultWidthHeightRatio: CGFloat = 1
}

struct StyleConstants {
    static let mainScreenFontSize: CGFloat = 30
    static let mainScreenIconOpacity: Double = 0.3
    static let mainScreenIconSize: CGFloat = 70
    static let explanationFontSize: CGFloat = 20
    static let edgePadding: CGFloat = 30
    static let onboardingPadding: CGFloat = 10
    
    static let toastDuration: Double = 8.0
    
    static let overlayOpacity: Double = 0.5
    static let textBackgroundOpacity: Double = 0.7
    static let overlayStrokeWidth: CGFloat = 5
    static let roundedCornerRadius: CGFloat = 15
    static let roundedCornerStrokeLength: CGFloat = 15
}

struct MenuConstants {
    static let killButtonClickCountActivate: Int = 5
    static let killButtonClickCountAlert: Int = 2
    enum ToastType {
        case clickToKill, killSuccess
    }
}

struct QrParserConstants {
    static let separator: String = ";"
    static let specifier: String = ":"
    static let appId = "CARWATCH"
    static let studyNameProperty: String = "N";
    static let studyDaysProperty: String = "D";
    static let numParticipantsProperty: String = "NP";
    static let salivaDistancesProperty: String = "T";
    static let salivaTimesProperty: String = "A";
    static let startSampleProperty: String = "SS";
    static let eveningProperty: String = "E";
    static let contactProperty: String = "M";
    static let duplicatesProperty: String = "FD";
    static let participantIdProperty: String = "PID";
}
