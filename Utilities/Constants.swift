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
    enum WakeupToastType {
        case feedbackToast, wakeupReportedToast, studyFinishedToast
    }
    enum BedtimeToastType {
        case feedbackToast, eveningSampleTakenToast
    }
}

struct AlarmConstants {
    static let initialAlarmId = "initial"
    static let timedAlarmId = "timed"
    static let eveningAlarmId = "evening"
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
        case clickToKill, killSuccess, zipLogsFailed
    }
}

struct QrParserConstants {
    static let separator: String = ";"
    static let listSeparator: String = ","
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

struct LoggerConstants {
    public static let loggerActionAppMetadata = "app_metadata"
    public static let loggerActionPhoneMetadata = "phone_metadata"
    public static let loggerActionAlarmSet = "alarm_set" // check
    public static let loggerActionAlarmCancel = "alarm_cancel" // check
    public static let loggerActionAlarmReceived = "alarm_received" // check
    public static let loggerActionAlarmKillAll = "alarm_killall" // check
    public static let loggerActionEveningSalivette = "evening_salivette"
    public static let loggerActionBarcodeScanInit = "barcode_scan_init"// check
    public static let loggerActionBarcodeScanned = "barcode_scanned"
    public static let loggerActionInvalidBarcodeScanned = "invalid_barcode_scanned"
    public static let loggerActionDuplicateBarcodeScanned = "duplicate_barcode_scanned"
    public static let loggerActionSpontaneousAwakening = "spontaneous_awakening" // check
    public static let loggerActionLightsOut = "lights_out" // check
    public static let loggerActionLightsOn = "lights_on" // check
    public static let loggerActionDayFinished = "day_finished" // check
    public static let loggerActionParticipantIdSet = "participant_id_set" // check
    public static let loggerActionStudyData = "study_metadata"

    public static let loggerExtraAlarmId = "id" // c
    public static let loggerExtraAlarmTimestamp = "timestamp" // c
    public static let loggerTranslatedTimestamp = "translated_timestamp" // c
    public static let loggerExtraAlarmSource = "source"
    public static let loggerExtraSalivaId = "saliva_id"
    public static let loggerExtraBarcodeValue = "barcode_value"
    public static let loggerExtraOtherBarcodes = "other_barcodes"
    public static let loggerExtraDayCounter = "day_counter" // c
    public static let loggerExtraParticipantId = "participant_id" // c
    public static let loggerExtraScannedDay = "day_scanned"
    public static let loggerExtraExpectedDay = "day_expected"
    public static let loggerExtraScannedSample = "sample_scanned" 
    public static let loggerExtraExpectedSample = "sample_expected" 
    public static let loggerExtraAppVersionCode = "version_code"
    public static let loggerExtraAppVersionName = "version_name"
    public static let loggerExtraPhoneBrand = "brand"
    public static let loggerExtraPhoneManufacturer = "manufacturer"
    public static let loggerExtraPhoneModel = "model"
    public static let loggerExtraPhoneVersionSdkLevel = "version_sdk_level"
    public static let loggerExtraPhoneVersionSecurityPatch = "version_security_patch"
    public static let loggerExtraPhoneVersionRelease = "version_release"
    public static let loggerExtraDisplayNightMode = "display_night_mode"
    
    public static let loggerExtraStudyName = "study_name"
    public static let loggerExtraNumParticipants = "num_participants"
    public static let loggerExtraSalivaDistances = "saliva_times"
    public static let loggerExtraSalivaTimes = "saliva_absolute_times"
    public static let loggerExtraStudyDays = "study_days"
    public static let loggerExtraHasEveningSalivette = "has_evening_salivette"
    public static let loggerExtraShareEmailAddress = "share_email_address"
    public static let loggerExtraCheckDuplicates = "check_duplicates"
    public static let loggerExtraSalivaIds = "saliva_ids"
}
