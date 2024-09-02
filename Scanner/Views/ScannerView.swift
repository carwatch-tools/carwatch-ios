import SwiftUI

struct ScannerView: View {
    @EnvironmentObject var alarmVM: AlarmViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    
    @Binding var isPresented: Bool
    @Binding var alarmId: String?
    @State var alertPresented: Bool = false
    @State var alertType: ScannerConstants.AlertType = .success
    @State var scanResult: String = ""
    @State var codeType: ScannerConstants.CodeType
    
    private let rotationChangePublisher = NotificationCenter.default
        .publisher(for: UIDevice.orientationDidChangeNotification)
    
    var body: some View {
        GeometryReader { geometry in
            let overlayWidthHeightRatio = codeType == ScannerConstants.CodeType.ean8 ? ScannerConstants.barcodeWidthHeightRatio : ScannerConstants.defaultWidthHeightRatio
            ZStack{
                CodeScanner(completion: handleScanResult, validation: validateScanResult, codeType: codeType, overlayWidthHeightRatio: overlayWidthHeightRatio)
                ScanOverlayView(overlayWidthHeightRatio: overlayWidthHeightRatio)
            }
        }
        .alert(isPresented: $alertPresented) {
            switch alertType {
            case .success:
                return Alert(title: Text("Scan succesful! Barcode data: \(scanResult)"),
                      dismissButton: Alert.Button.default(
                        Text("OK"), action: {
                            // go back to main view
                            alertPresented = false
                            isPresented = false
                        }
                      )
                )
            case .invalid:
                let type = codeType == .ean8 ? "Barcode" : "QR code"
                return Alert(title: Text("\(type) invalid! Please make sure you have scanned the correct \(type) and try again."),
                      dismissButton: Alert.Button.default(
                        Text("OK"), action: {
                            // go back to main view
                            alertPresented = false
                        }
                      )
                )
            }
        }
    }
    
    func validateScanResult(result: String) -> Bool {
        switch codeType {
        case .ean8:
            // TODO
            return true
        case .qr:
            studyDataVM.parseQrCodeData(result)
            let isValid = studyDataVM.studyData.isValid
            if !isValid {
                alertType = .invalid
                alertPresented = true
            }
            return isValid
        }
    }
    
    func handleScanResult(result: Result<String, ScanError>){
        switch result {
        case .success(let result):
            print("scan successful. result: \(result)")
            scanResult = result
            alertType = .success
            alertPresented = true
            switch codeType {
            case .ean8:
                alarmVM.setCurrentAlarmScanned(alarmId: alarmId)
                // reset app delegate status
                appDelegate.openedFromNotification = false
            case .qr:
                sessionVM.startTutorial()
            }
        case .failure(let error):
            print("Scanning failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    @State var isPresented = true
    @State var currentAlarmId: String? = nil
    @StateObject var alarmViewModel: AlarmViewModel = AlarmViewModel()
    @StateObject var sessionViewModel: SessionViewModel = SessionViewModel()
    @StateObject var studyDataViewModel: StudyDataViewModel = StudyDataViewModel()
    
    return ScannerView(isPresented: $isPresented, alarmId: $currentAlarmId, codeType: ScannerConstants.CodeType.ean8)
        .environmentObject(alarmViewModel)
        .environmentObject(sessionViewModel)
        .environmentObject(studyDataViewModel)
}

