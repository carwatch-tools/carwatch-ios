import UIKit
import SwiftUI

struct ActivityViewController: UIViewControllerRepresentable {
    /// general share dialog for sharing the app logs
    
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    var subject: String
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        print("ui view controller")
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        
        // Set the subject for email (optional, only works for mail-based apps)
        controller.setValue(subject, forKey: "subject")
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}
