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
            // TODO: add explanation alerts for invalid cases
        case .ean8:
            if sessionVM.scannedBarcodes.contains(result) {
                // duplicate Barcode
                var msg = [String: Any]()
                msg[LoggerConstants.loggerExtraBarcodeValue] = result
                msg[LoggerConstants.loggerExtraOtherBarcodes] = sessionVM.scannedBarcodes
                Logger.instance.log(tag: LoggerConstants.loggerActionDuplicateBarcodeScanned, message: msg)
                return false
            }
            
            // check if barcode is valid
            if let (participantId, dayId, salivaId) = parseBarcodeScanResult(result) {
                if(participantId <= studyDataVM.studyData.numParticipants && dayId <= studyDataVM.studyData.studyDays && salivaId <= studyDataVM.studyData.numSamples) {
                    return true
                }
            }
            
            // invalid barcode
            var msg = [String: Any]()
            msg[LoggerConstants.loggerExtraBarcodeValue] = result
            Logger.instance.log(tag: LoggerConstants.loggerActionInvalidBarcodeScanned, message: msg)
            return false
            
        case .qr:
            studyDataVM.parseQrCodeData(result)
            let isValid = studyDataVM.studyData.isValid
            if !isValid {
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
                if let (_, scannedDayId, scannedSalivaId) = parseBarcodeScanResult(result) {
                    let samplePrefix = studyDataVM.studyData.startSample.prefix(1)
                    if let startIndex = Int(studyDataVM.studyData.startSample.dropFirst())
                    {
                        let eveningSampleIndex = studyDataVM.studyData.hasEveningSample ? studyDataVM.studyData.numSamples - 1 + startIndex : -1
                        let salivaId = alarmId == AlarmConstants.eveningAlarmId ? eveningSampleIndex : alarmId + startIndex
                        let salivaDayId = alarmVM.studyDayCounter * 100 + salivaId
                        let scannedSample = "\(samplePrefix)\(scannedSalivaId == eveningSampleIndex ? AlarmConstants.eveningAlarmLoggerPrefix : String(scannedSalivaId))"
                        let expectedSample = "\(samplePrefix)\(alarmId == AlarmConstants.eveningAlarmId ? AlarmConstants.eveningAlarmLoggerPrefix : alarmId + startIndex)"
                        
                        var msg = [String: Any]()
                        msg[LoggerConstants.loggerExtraAlarmId] = alarmId // TODO: does this work?
                        msg[LoggerConstants.loggerExtraSalivaId] = salivaDayId
                        msg[LoggerConstants.loggerExtraBarcodeValue] = result
                        msg[LoggerConstants.loggerExtraScannedDay] = scannedDayId
                        msg[LoggerConstants.loggerExtraExpectedDay] = alarmVM.numStudyDays
                        msg[LoggerConstants.loggerExtraScannedSample] = scannedSample
                        msg[LoggerConstants.loggerExtraExpectedSample] = expectedSample
                        Logger.instance.log(tag: LoggerConstants.loggerActionBarcodeScanned, message: msg)
                    }
                }
                let scannedDay = result
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
    
    private func parseBarcodeScanResult(_ result: String) -> (Int, Int, Int)? {
        if let barcodeValue = Int(result) {
            let participantId = barcodeValue / 10000
            let dayId = (barcodeValue / 100) % 100
            let salivaId = barcodeValue % 100
            return (participantId, dayId, salivaId)
        }
        return nil
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

