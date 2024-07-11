import SwiftUI

struct PermissionConstants {
    enum PermissionType {
        case notifications, camera
    }
    
    static let appSettingsUrl = URL(string: UIApplication.openSettingsURLString)
}

struct StyleConstants {
    static let mainScreenFontSize: CGFloat = 30
    static let mainScreenIconOpacity: Double = 0.3
    static let mainScreenIconSize: CGFloat = 70
    static let explanationFontSize: CGFloat = 20
    static let edgePadding: CGFloat = 30
    
    static let alertDuration: Double = 8.0
}

