import SwiftUI
import SafariServices

struct PrivacyPolicyView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let viewController = SFSafariViewController(url: AppConstants.privacyPolicyURL)
        viewController.dismissButtonStyle = .done
        return viewController
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}

#Preview {
    PrivacyPolicyView()
}
