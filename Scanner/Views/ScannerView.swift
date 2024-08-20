import SwiftUI

struct ScannerView: View {
    @EnvironmentObject var avm: AlarmViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    
    @Binding var isPresented: Bool
    @Binding var alarmId: String?
    @State var isSuccessful: Bool = false
    @State var scanResult: String = ""
    @State var codeType: ScannerConstants.CodeType
    
    private let rotationChangePublisher = NotificationCenter.default
        .publisher(for: UIDevice.orientationDidChangeNotification)
    
    var body: some View {
        GeometryReader { geometry in
            let overlayWidthHeightRatio = codeType == ScannerConstants.CodeType.ean8 ? ScannerConstants.barcodeWidthHeightRatio : ScannerConstants.defaultWidthHeightRatio
            ZStack{
                CodeScanner(completion: handleScanResult, codeType: codeType, overlayWidthHeightRatio: overlayWidthHeightRatio)
                ScanOverlayView(overlayWidthHeightRatio: overlayWidthHeightRatio)
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
            avm.setCurrentAlarmScanned(alarmId: alarmId)
            // reset app delegate status
            appDelegate.openedFromNotification = false
            
        case .failure(let error):
            print("Scanning failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    @State var isPresented = true
    @State var currentAlarmId: String? = nil
    @StateObject var alarmViewModel: AlarmViewModel = AlarmViewModel()
    
    return ScannerView(isPresented: $isPresented, alarmId: $currentAlarmId, codeType: ScannerConstants.CodeType.ean8).environmentObject(alarmViewModel)
}

