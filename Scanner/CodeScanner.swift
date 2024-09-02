import SwiftUI

struct CodeScanner : UIViewControllerRepresentable {
    
    typealias UIViewControllerType = CodeScannerViewController
    public var completion: (Result<String, ScanError>) -> Void
    public var validation: (String) -> Bool

    let codeType: ScannerConstants.CodeType
    let overlayWidthHeightRatio: CGFloat
    
    func makeUIViewController(context: Context) -> CodeScannerViewController {
        return CodeScannerViewController(parentView: self, codeType: codeType, codeWidthHeightRatio: overlayWidthHeightRatio)
    }
    
    func updateUIViewController(_ uiViewController: CodeScannerViewController, context: Context) {
        uiViewController.parentView = self
    }
}

