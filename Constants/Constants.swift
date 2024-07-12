import SwiftUI

struct PermissionConstants {
    enum PermissionType {
        case notifications, camera
    }
    
    static let appSettingsUrl = URL(string: UIApplication.openSettingsURLString)
}

struct ScannerConstants {
    enum CodeType {
        case ean8, qr
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
    
    static let alertDuration: Double = 8.0
    
    static let overlayOpacity: Double = 0.5
    static let overlayStrokeWidth: CGFloat = 5
    static let roundedCornerRadius: CGFloat = 15
    static let roundedCornerStrokeLength: CGFloat = 15
}

