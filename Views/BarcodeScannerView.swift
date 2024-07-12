import SwiftUI
import CodeScanner

struct BarcodeScannerView: View {
    @State var isPresented = false
    var body: some View {
        Button("scanner view"){
            isPresented = true
        }
        .sheet(isPresented: $isPresented) {
            BarcodeScannerViewWithOverlay(isPresented: $isPresented)
        }
        .interactiveDismissDisabled()
    }
}

struct BarcodeScannerViewWithOverlay: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack{
            CodeScannerView(codeTypes: [.ean8], simulatedData: "1234567", completion: handleScanResult)
            //                .padding(.horizontal, 40)
            //                .frame(width: 350, height: 250)
            ScanOverlayView(codeType: ScannerConstants.CodeType.ean8)
        }
    }
    
    func handleScanResult(result: Result<ScanResult, ScanError>){
        isPresented = false
        switch result {
        case .success(let result):
            let details = result.string.components(separatedBy: ".")
            // data validation
            guard details.count == 1 else { return }
            // process scanned data
            // ..
        case .failure(let error):
            print("Scanning failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    BarcodeScannerView()
}
