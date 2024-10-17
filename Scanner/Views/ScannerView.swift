import SwiftUI

struct ScannerView: View {
    @EnvironmentObject var alarmVM: AlarmViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel

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
                CodeScanner(completion: handleScanResult, validation: validateScanResult, codeType: codeType, overlayWidthHeightRatio: overlayWidthHeightRatio)
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
    
    func validateScanResult(result: String) -> Bool {
        switch codeType {
        case .ean8:
            // TODO: add explanation alert & validation
            //
            // Duplicate Barcode:
            // var msg = [String: Any]()
            // msg[LoggerConstants.loggerExtraBarcodeValue] = result
            // msg[LoggerConstants.loggerExtraOtherBarcodes] = scannedBarcodes
            // Logger.instance.log(tag: LoggerConstants.loggerActionDuplicateBarcodeScanned, message: msg)
            // Invalid barcode
            // var msg = [String: Any]()
            // msg[LoggerConstants.loggerExtraBarcodeValue] = result
            // Logger.instance.log(tag: LoggerConstants.loggerActionInvalidBarcodeScanned, message: msg)
            return true
        case .qr:
            studyDataVM.parseQrCodeData(result)
            let isValid = studyDataVM.studyData.isValid
            if !isValid {
                // TODO: add explanation alert
                var msg = [String: Any]()
                msg[LoggerConstants.loggerExtraBarcodeValue] = result
                Logger.instance.log(tag: LoggerConstants.loggerActionInvalidBarcodeScanned, message: msg)
            }
            return isValid
        }
    }
    
    func handleScanResult(result: Result<String, ScanError>){
        switch result {
        case .success(let result):
            print("scan successful. result: \(result)")

            scanResult = result
            isSuccessful = true
            switch codeType {
            case .ean8:
                alarmVM.setCurrentAlarmScanned(alarmId: alarmId)
                
                // TODO: fix this
                var msg = [String: Any]()
                msg[LoggerConstants.loggerExtraAlarmId] = result
                msg[LoggerConstants.loggerExtraSalivaId] = result
                msg[LoggerConstants.loggerExtraBarcodeValue] = result
                msg[LoggerConstants.loggerExtraScannedDay] = result
                msg[LoggerConstants.loggerExtraExpectedDay] = result
                msg[LoggerConstants.loggerExtraScannedSample] = result
                msg[LoggerConstants.loggerExtraExpectedSample] = result
                Logger.instance.log(tag: LoggerConstants.loggerActionBarcodeScanned, message: msg)
                
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

