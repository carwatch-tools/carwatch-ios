import SwiftUI
import UIKit

enum BarcodeResult {
    case valid
    case invalid
    case duplicate
    case wrongSample
}

struct ScannerView: View {
    @AccessibilityFocusState private var isBackButtonFocused: Bool
    @EnvironmentObject var alarmVM: AlarmViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    
    @Binding var isPresented: Bool
    @Binding var alarmId: Int?
    @Binding var pendingWakeupConfirmationTime: Date?
    @State var showAlert: Bool = false
    @State var alertType: ScannerConstants.AlertType = .invalid
    @State var scanResult: String = ""
    @State var codeType: ScannerConstants.CodeType
    @State private var didAcceptScanInCurrentSession = false
    
    private let rotationChangePublisher = NotificationCenter.default
        .publisher(for: UIDevice.orientationDidChangeNotification)

    private var scannedCodeLabel: String {
        localizedAppString(codeType == .qr ? "QR code" : "barcode")
    }

    private var scannerPromptText: LocalizedStringKey {
        codeType == .qr ? "Please point your camera at a QR code!" : "Please point your camera at a barcode!"
    }

    private var scannerScreenAnnouncement: String {
        codeType == .qr ? localizedAppString("QR code scanner opened. Please point your camera at a QR code.") : localizedAppString("Barcode scanner opened. Please point your camera at a barcode.")
    }
    
    var body: some View {
        GeometryReader { geometry in
            let overlayWidthHeightRatio = codeType == ScannerConstants.CodeType.ean8 ? ScannerConstants.barcodeWidthHeightRatio : ScannerConstants.defaultWidthHeightRatio
            ZStack{
                CodeScanner(completion: handleScanResult, validation: validateScanResult, codeType: codeType, overlayWidthHeightRatio: overlayWidthHeightRatio)
                    .accessibilityHidden(true)
                ScanOverlayView(overlayWidthHeightRatio: overlayWidthHeightRatio, promptText: scannerPromptText)
            }
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            didAcceptScanInCurrentSession = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isBackButtonFocused = true
                postAccessibilityScreenChanged(nil)
                postAccessibilityAnnouncement(scannerScreenAnnouncement)
            }
        }
        .onDisappear {
            appDelegate.resetNotificationNavigationState()
        }
        .onChange(of: showAlert) { isPresented in
            guard isPresented else {
                return
            }

            switch alertType {
            case .success:
                postAccessibilityAnnouncement(localizedAppString("Scan successful."))
            case .invalid:
                postAccessibilityAnnouncement(localizedAppString("Invalid code scanned."))
            case .duplicate:
                postAccessibilityAnnouncement(localizedAppString("Duplicate barcode scanned."))
            case .wrongSample:
                postAccessibilityAnnouncement(localizedAppString("Wrong sample barcode scanned."))
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Button {
                    dismissScanner()
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                        .font(.headline)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .accessibilityIdentifier("scanner.back")
                .accessibilityFocused($isBackButtonFocused)
                .accessibilityHint(localizedAppString("Closes the scanner and returns to the previous screen."))

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
                                    dismissScanner()
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
            case .wrongSample:
                return Alert(title: Text("Invalid Barcode"), message: Text("This barcode belongs to another sample. Please scan the barcode with ID \(expectedHumanReadableBarcodeId())."),
                             dismissButton: Alert.Button.default(
                                Text("OK"), action: {
                                    showAlert = false
                                }
                             )
                )
            }
            
        }
    }
    
    func validateScanResult(result: String) -> Bool {
        guard !didAcceptScanInCurrentSession else {
            return false
        }

        switch codeType {
        case .ean8:
            // remove check digit
            let barcodeData = String(result.dropLast(1))
            let validationResult = validateBarcode(
                barcode: barcodeData,
                fdEnabled: studyDataVM.studyData.isCheckDuplicatesEnabled,
                scannedBarcodes: Set(sessionVM.scannedBarcodes),
                numParticipants: studyDataVM.studyData.numParticipants,
                numDays: studyDataVM.studyData.studyDays,
                totalNumSamples: studyDataVM.studyData.numSamples,
                currentDay: alarmVM.studyDayCounter,
                expectedSalivaId: expectedSalivaId(),
                startSampleIndex: startSampleIndex()
            )

            switch validationResult {
            case .valid:
                return true
            case .duplicate:
                alertType = .duplicate
                showAlert = true
                var msg = [String: Any]()
                msg[LoggerConstants.loggerExtraBarcodeValue] = barcodeData
                msg[LoggerConstants.loggerExtraOtherBarcodes] = sessionVM.scannedBarcodes
                Logger.instance.log(tag: LoggerConstants.loggerActionDuplicateBarcodeScanned, message: msg)
                return false
            case .wrongSample:
                alertType = .wrongSample
                showAlert = true
                logRejectedBarcode(barcodeData)
                return false
            case .invalid:
                alertType = .invalid
                showAlert = true
                logRejectedBarcode(barcodeData)
                return false
            }
            
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

    func validateBarcode(
        barcode: String,
        fdEnabled: Bool,
        scannedBarcodes: Set<String>,
        numParticipants: Int,
        numDays: Int,
        totalNumSamples: Int,
        currentDay: Int,
        expectedSalivaId: Int,
        startSampleIndex: Int
    ) -> BarcodeResult {
        if !fdEnabled {
            return .valid
        }

        if scannedBarcodes.contains(barcode) {
            return .duplicate
        }

        guard let barcodeValue = Int(barcode) else {
            return .invalid
        }

        let participantId = barcodeValue / 10000
        let dayId = (barcodeValue / 100) % 100
        let salivaId = barcodeValue % 100
        let lastSampleIndex = startSampleIndex + totalNumSamples - 1

        guard participantId <= numParticipants,
              dayId <= numDays,
              totalNumSamples > 0,
              salivaId >= startSampleIndex,
              salivaId <= lastSampleIndex else {
            return .invalid
        }

        let expectedSampleId = expectedSalivaId + startSampleIndex

        guard dayId == currentDay,
              salivaId == expectedSampleId else {
            return .wrongSample
        }

        return .valid
    }
    
    func handleScanResult(result: Result<String, ScanError>){
        guard !didAcceptScanInCurrentSession else {
            return
        }

        switch result {
        case .success(let result):
            didAcceptScanInCurrentSession = true
            alertType = .success
            showAlert = true
            switch codeType {
            case .ean8:
                // remove check digit
                scanResult = String(result.dropLast(1))
                sessionVM.scannedBarcodes.append(scanResult)
                if let pendingWakeupConfirmationTime {
                    alarmVM.confirmWakeup(at: pendingWakeupConfirmationTime)
                    self.pendingWakeupConfirmationTime = nil
                }
                handleSuccessfulEanScan()
            case .qr:
                scanResult = result
                sessionVM.startStudyConfirmation()
                postAccessibilityAnnouncement(localizedAppString("Study QR code accepted. Opening study details."))
            }
        case .failure:
            break
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

    private func startSampleIndex() -> Int {
        Int(studyDataVM.studyData.startSample.dropFirst()) ?? 0
    }

    private func expectedSalivaId() -> Int {
        if alarmId == AlarmConstants.eveningAlarmId {
            return studyDataVM.studyData.eveningSampleId
        }

        if let alarmId {
            return alarmId
        }

        return alarmVM.getNextUpcomingAlarm()?.id ?? 0
    }

    private func expectedHumanReadableBarcodeId() -> String {
        let samplePrefix = String(studyDataVM.studyData.startSample.prefix(1))
        let sampleId: String

        if alarmId == AlarmConstants.eveningAlarmId {
            sampleId = "\(samplePrefix)\(AlarmConstants.eveningAlarmLoggerPrefix)"
        } else {
            sampleId = "\(samplePrefix)\(expectedSalivaId() + startSampleIndex())"
        }

        let participantId = studyDataVM.studyData.participantId.trimmingCharacters(in: .whitespacesAndNewlines)
        if participantId.isEmpty {
            return sampleId
        }

        if studyDataVM.studyData.studyDays > 1 {
            return "\(participantId)_D\(alarmVM.studyDayCounter)_\(sampleId)"
        }

        return "\(participantId)_\(sampleId)"
    }

    private func logRejectedBarcode(_ barcode: String) {
        var msg = [String: Any]()
        msg[LoggerConstants.loggerExtraBarcodeValue] = barcode
        Logger.instance.log(tag: LoggerConstants.loggerActionInvalidBarcodeScanned, message: msg)
    }
    
    private func handleSuccessfulEanScan(){
        logEanScanData()
        alarmVM.setCurrentAlarmScanned(alarmId: alarmId)
        appDelegate.resetNotificationNavigationState()
    }

    private func dismissScanner() {
        appDelegate.resetNotificationNavigationState()
        pendingWakeupConfirmationTime = nil
        isPresented = false
    }
    
    private func logEanScanData(){
        let samplePrefix = studyDataVM.studyData.startSample.prefix(1)
        let startIndex = startSampleIndex()

        if alarmId == nil {
            if let alarm = alarmVM.getNextUpcomingAlarm(){
                alarmId = alarm.id
            } else {
                alarmId = -1
            }
        }

        let eveningSampleIndex = studyDataVM.studyData.hasEveningSample ? studyDataVM.studyData.numSamples - 1 + startIndex : -1
        let expectedSalivaId = alarmId == AlarmConstants.eveningAlarmId ? eveningSampleIndex : alarmId! + startIndex
        let salivaDayId = alarmVM.studyDayCounter * 100 + expectedSalivaId
        let expectedSample = "\(samplePrefix)\(alarmId == AlarmConstants.eveningAlarmId ? AlarmConstants.eveningAlarmLoggerPrefix : String(expectedSalivaId))"

        var msg = [String: Any]()
        msg[LoggerConstants.loggerExtraAlarmId] = alarmId
        msg[LoggerConstants.loggerExtraSalivaId] = salivaDayId
        msg[LoggerConstants.loggerExtraBarcodeValue] = scanResult
        msg[LoggerConstants.loggerExtraExpectedDay] = alarmVM.studyDayCounter
        msg[LoggerConstants.loggerExtraExpectedSample] = expectedSample

        if let (_, scannedDayId, scannedSalivaId) = parseBarcodeScanResult(scanResult) {
            let scannedSample = "\(samplePrefix)\(scannedSalivaId == eveningSampleIndex ? AlarmConstants.eveningAlarmLoggerPrefix : String(scannedSalivaId))"
            msg[LoggerConstants.loggerExtraScannedDay] = scannedDayId
            msg[LoggerConstants.loggerExtraScannedSample] = scannedSample
        }

        Logger.instance.log(tag: LoggerConstants.loggerActionBarcodeScanned, message: msg)
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
                    pendingWakeupConfirmationTime: .constant(nil),
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
