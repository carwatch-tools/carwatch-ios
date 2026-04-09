import SwiftUI

struct ScannerView: View {
    @EnvironmentObject var alarmVM: AlarmViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    
    @Binding var isPresented: Bool
    @Binding var alarmId: Int?
    @State var showAlert: Bool = false
    @State var alertType: ScannerConstants.AlertType = .invalid
    @State var scanResult: String = ""
    @State var codeType: ScannerConstants.CodeType
    
    private let rotationChangePublisher = NotificationCenter.default
        .publisher(for: UIDevice.orientationDidChangeNotification)

    private var scannedCodeLabel: String {
        localizedAppString(codeType == .qr ? "QR code" : "barcode")
    }

    private var scannerPromptText: LocalizedStringKey {
        codeType == .qr ? "Please point your camera at a QR code!" : "Please point your camera at a barcode!"
    }
    
    var body: some View {
        GeometryReader { geometry in
            let overlayWidthHeightRatio = codeType == ScannerConstants.CodeType.ean8 ? ScannerConstants.barcodeWidthHeightRatio : ScannerConstants.defaultWidthHeightRatio
            ZStack{
                CodeScanner(completion: handleScanResult, validation: validateScanResult, codeType: codeType, overlayWidthHeightRatio: overlayWidthHeightRatio)
                ScanOverlayView(overlayWidthHeightRatio: overlayWidthHeightRatio, promptText: scannerPromptText)
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Button {
                    isPresented = false
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                        .font(.headline)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .alert(isPresented: $showAlert) {
            switch alertType {
            case .success:
                return Alert(title: Text("The \(scannedCodeLabel) was scanned successfully!"),
                             dismissButton: Alert.Button.default(
                                Text("OK"), action: {
                                    // go back to main view
                                    showAlert = false
                                    isPresented = false
                                }
                             )
                )
            case .invalid:
                return Alert(title: Text("Invalid \(scannedCodeLabel)!"),
                             dismissButton: Alert.Button.default(
                                Text("OK"), action: {
                                    // go back to main view
                                    showAlert = false
                                }
                             )
                )
            case .duplicate:
                return Alert(title: Text("Duplicate \(scannedCodeLabel)!"), message: Text("This barcode was already scanned before. Please check and make sure to use a new salivette."),
                             dismissButton: Alert.Button.default(
                                Text("OK"), action: {
                                    // go back to main view
                                    showAlert = false
                                }
                             )
                )
            }
            
        }
    }
    
    func validateScanResult(result: String) -> Bool {
        switch codeType {
        case .ean8:
            // remove check digit
            let barcodeData = String(result.dropLast(1))
            if  studyDataVM.studyData.isCheckDuplicatesEnabled && sessionVM.scannedBarcodes.contains(barcodeData) {
                // duplicate Barcode
                alertType = .duplicate
                showAlert = true
                var msg = [String: Any]()
                msg[LoggerConstants.loggerExtraBarcodeValue] = barcodeData
                msg[LoggerConstants.loggerExtraOtherBarcodes] = sessionVM.scannedBarcodes
                Logger.instance.log(tag: LoggerConstants.loggerActionDuplicateBarcodeScanned, message: msg)
                return false
            }
            
            // check if barcode is valid
            if let (participantId, dayId, salivaId) = parseBarcodeScanResult(barcodeData) {
                if(participantId <= studyDataVM.studyData.numParticipants && dayId <= studyDataVM.studyData.studyDays && salivaId <= studyDataVM.studyData.numSamples) {
                    print("Barcode \(barcodeData) is valid")
                    return true
                }
            }
            
            // invalid barcode
            alertType = .invalid
            showAlert = true
            var msg = [String: Any]()
            msg[LoggerConstants.loggerExtraBarcodeValue] = barcodeData
            Logger.instance.log(tag: LoggerConstants.loggerActionInvalidBarcodeScanned, message: msg)
            print("Barcode \(barcodeData) is invalid")
            return false
            
        case .qr:
            studyDataVM.parseQrCodeData(result)
            let isValid = studyDataVM.studyData.isValid
            if !isValid {
                var msg = [String: Any]()
                msg[LoggerConstants.loggerExtraBarcodeValue] = result
                Logger.instance.log(tag: LoggerConstants.loggerActionInvalidBarcodeScanned, message: msg)
            }
            print("QR code valid: \(isValid)")
            return isValid
        }
    }
    
    func handleScanResult(result: Result<String, ScanError>){
        switch result {
        case .success(let result):
            print("Scan successful with result: \(result)")
            alertType = .success
            showAlert = true
            switch codeType {
            case .ean8:
                // remove check digit
                scanResult = String(result.dropLast(1))
                sessionVM.scannedBarcodes.append(scanResult)
                handleSuccessfulEanScan()
            case .qr:
                scanResult = result
                sessionVM.startStudyConfirmation()
            }
        case .failure(let error):
            print("Scan failed: \(error.localizedDescription)")
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
    
    private func handleSuccessfulEanScan(){
        logEanScanData()
        alarmVM.setCurrentAlarmScanned(alarmId: alarmId)
        // reset app delegate status
        appDelegate.openedFromNotification = false
    }
    
    private func logEanScanData(){
        if let (_, scannedDayId, scannedSalivaId) = parseBarcodeScanResult(scanResult) {
            let samplePrefix = studyDataVM.studyData.startSample.prefix(1)
            if let startIndex = Int(studyDataVM.studyData.startSample.dropFirst())
            {
                if alarmId == nil {
                    if let alarm = alarmVM.getNextUpcomingAlarm(){
                        alarmId = alarm.id
                    } else {
                        alarmId = -1
                    }
                }
                let eveningSampleIndex = studyDataVM.studyData.hasEveningSample ? studyDataVM.studyData.numSamples - 1 + startIndex : -1
                let salivaId = alarmId == AlarmConstants.eveningAlarmId ? eveningSampleIndex : alarmId! + startIndex
                let salivaDayId = alarmVM.studyDayCounter * 100 + salivaId
                let scannedSample = "\(samplePrefix)\(scannedSalivaId == eveningSampleIndex ? AlarmConstants.eveningAlarmLoggerPrefix : String(scannedSalivaId))"
                let expectedSample = "\(samplePrefix)\(alarmId == AlarmConstants.eveningAlarmId ? AlarmConstants.eveningAlarmLoggerPrefix : String(alarmId! + startIndex))"
                
                var msg = [String: Any]()
                msg[LoggerConstants.loggerExtraAlarmId] = alarmId
                msg[LoggerConstants.loggerExtraSalivaId] = salivaDayId
                msg[LoggerConstants.loggerExtraBarcodeValue] = scanResult
                msg[LoggerConstants.loggerExtraScannedDay] = scannedDayId
                msg[LoggerConstants.loggerExtraExpectedDay] = alarmVM.studyDayCounter
                msg[LoggerConstants.loggerExtraScannedSample] = scannedSample
                msg[LoggerConstants.loggerExtraExpectedSample] = expectedSample
                Logger.instance.log(tag: LoggerConstants.loggerActionBarcodeScanned, message: msg)
            }
        }
    }
}

#Preview("Interactive ScannerView") {
    struct PreviewContainer: View {
        @State private var isPresented: Bool = true
        @State private var currentAlarmId: Int? = 0
        @StateObject private var alarmViewModel = AlarmViewModel()
        @StateObject private var sessionViewModel = SessionViewModel()
        @StateObject private var studyDataViewModel = StudyDataViewModel()
        // Provide an AppDelegate instance for the environment
        @StateObject private var appDelegate = AppDelegate()

        var body: some View {
            NavigationStack {
                ScannerView(
                    isPresented: $isPresented,
                    alarmId: $currentAlarmId,
                    codeType: ScannerConstants.CodeType.ean8
                )
                .environmentObject(alarmViewModel)
                .environmentObject(sessionViewModel)
                .environmentObject(studyDataViewModel)
                .environmentObject(appDelegate)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isPresented ? "Dismiss" : "Present") {
                            isPresented.toggle()
                        }
                    }
                }
            }
        }
    }
    return PreviewContainer()
}
