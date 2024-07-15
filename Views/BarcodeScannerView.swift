import SwiftUI
import CodeScanner

struct BarcodeScannerView: View {
    //    TODO: to limit roi to overlay region, custom scanner is required: https://stackoverflow.com/questions/43738394/ios-swift-how-to-use-rectofinterest-correctly-barcode-scanner
    @State var isPresented = true
    @State var isSuccessful = false
    var body: some View {
        EmptyView()
            .sheet(isPresented: $isPresented) {
                BarcodeScannerViewWithOverlay(isPresented: $isPresented, isSuccessful: $isSuccessful)
                    .interactiveDismissDisabled()
            }
    }
}

struct BarcodeScannerViewWithOverlay: View {
    @EnvironmentObject var avm: AlarmViewModel
    
    @Binding var isPresented: Bool
    @Binding var isSuccessful: Bool
    @State var scanResult: String = ""
    
    var body: some View {
        ZStack{
            CodeScannerView(codeTypes: [.ean8], simulatedData: "1234567", completion: handleScanResult)
            ScanOverlayView(codeType: ScannerConstants.CodeType.ean8)
        }
        .alert(isPresented: $isSuccessful) {
            Alert(title: Text("Scan succesful! Barcode data: \(scanResult)"),
                  dismissButton: Alert.Button.default(
                    Text("OK"), action: {
                        // go back to main view
                        isSuccessful = false
                        isPresented = false
                    }
                  )
            )
        }
    }
    
    
    func handleScanResult(result: Result<ScanResult, ScanError>){
        switch result {
        case .success(let result):
            // let details = result.string.components(separatedBy: ".")
            // data validation
            // guard details.count == 1 else { return }
            // process scanned data
            // ..
            isSuccessful = true
            print("scan successful. result: \(result)")
            scanResult = result.string
            avm.setAlarmScanned()
            
        case .failure(let error):
            print("Scanning failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    BarcodeScannerView()
}
