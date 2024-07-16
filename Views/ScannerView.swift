import SwiftUI

struct ScannerView: View {
    //    TODO: prevent roation in scanning mode
    @EnvironmentObject var avm: AlarmViewModel
    
    @Binding var isPresented: Bool
    @Binding var isSuccessful: Bool
    @State var scanResult: String = ""
    @State var codeType: ScannerConstants.CodeType
    
    var body: some View {
        GeometryReader { geometry in
            let width: CGFloat = geometry.size.width/ScannerConstants.overlayWidthFactor
            let overlayWidthHeightRatio = codeType == ScannerConstants.CodeType.ean8 ? ScannerConstants.barcodeWidthHeightRatio : ScannerConstants.defaultWidthHeightRatio
            let height: CGFloat = width / overlayWidthHeightRatio
            let xPos = (geometry.size.width - width) / 2.0
            let yPos = (geometry.size.height - height) / 2.0
            ZStack{
                //            CodeScannerView(codeTypes: [.ean8], simulatedData: "1234567", completion: handleScanResult)
                CodeScanner(completion: handleScanResult, barcodeAreaWidth: width, barcodeAreaHeight: height, barcodeAreaXPos: xPos, barcodeAreaYPos: yPos, codeType: codeType)
                ScanOverlayView(barcodeAreaWidth: width, barcodeAreaHeight: height, barcodeAreaXPos: xPos, barcodeAreaYPos: yPos)
            }
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
    
    func handleScanResult(result: Result<String, ScanError>){
        switch result {
        case .success(let result):
            isSuccessful = true
            print("scan successful. result: \(result)")
            scanResult = result
            avm.setAlarmScanned()
            
        case .failure(let error):
            print("Scanning failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    @State var isPresented = true
    @State var isSuccessful = false
    @StateObject var alarmViewModel: AlarmViewModel = AlarmViewModel()
    
    return ScannerView(isPresented: $isPresented, isSuccessful: $isSuccessful, codeType: ScannerConstants.CodeType.ean8).environmentObject(alarmViewModel)
}

