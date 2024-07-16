import SwiftUI

struct CodeScanner : UIViewControllerRepresentable {
    
    typealias UIViewControllerType = CodeScannerViewController
    public var completion: (Result<String, ScanError>) -> Void
    
    let barcodeAreaWidth: CGFloat
    let barcodeAreaHeight: CGFloat
    let barcodeAreaXPos: CGFloat
    let barcodeAreaYPos: CGFloat
    let codeType: ScannerConstants.CodeType
    
    func makeUIViewController(context: Context) -> CodeScannerViewController {
        return CodeScannerViewController(parentView: self, codeType: codeType, barcodeAreaWidth: barcodeAreaWidth, barcodeAreaHeight: barcodeAreaHeight, barcodeAreaXPos: barcodeAreaXPos, barcodeAreaYPos: barcodeAreaYPos)
    }
    
    func updateUIViewController(_ uiViewController: CodeScannerViewController, context: Context) {
        uiViewController.parentView = self
    }
}

