import SwiftUI
import CodeScanner

struct BarcodeScannerView: View {
    //    TODO: to limit roi to overlay region, custom scanner is required: https://stackoverflow.com/questions/43738394/ios-swift-how-to-use-rectofinterest-correctly-barcode-scanner
    @State var isPresented = true
    var body: some View {
        Button("scanner view"){
            isPresented = true
        }
        .sheet(isPresented: $isPresented) {
            BarcodeScannerViewWithOverlay(isPresented: $isPresented)
                .interactiveDismissDisabled()
        }
    }
}

struct BarcodeScannerViewWithOverlay: View {
    @EnvironmentObject var avm: AlarmViewModel
    
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack{
            CodeScannerView(codeTypes: [.ean8], simulatedData: "1234567", completion: handleScanResult)
            ScanOverlayView(codeType: ScannerConstants.CodeType.ean8)
        }
    }
    
    func handleScanResult(result: Result<ScanResult, ScanError>){
        isPresented = false
        switch result {
        case .success(let result):
            // let details = result.string.components(separatedBy: ".")
            // data validation
            // guard details.count == 1 else { return }
            // process scanned data
            // ..
            print("scan successful. result: \(result)")
            avm.setAlarmScanned()
            
        case .failure(let error):
            print("Scanning failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    BarcodeScannerView()
}
