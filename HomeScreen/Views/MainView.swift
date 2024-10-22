import SwiftUI

struct MainView: View {
    @EnvironmentObject var permissionDataVM: PermissionDataViewModel
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    
    @State var isQrCodeScannerPresented = false
    @State var currentAlarmId: Int? = nil
    
    var body: some View {
        
        switch sessionVM.getCurrentState() {
        case .registration:
            if permissionDataVM.permissionData.cameraPermissionDialogHandled && !permissionDataVM.permissionData.cameraPermissionGranted {
                MissingPermissionView(type: PermissionConstants.PermissionType.camera)
                    .onAppear(){
                        permissionDataVM.checkCameraPermission()
                     }
            } else {
                RegistrationView(isScannerPresented: $isQrCodeScannerPresented)
                    .environmentObject(sessionVM)
                    .environmentObject(permissionDataVM)
                    .interactiveDismissDisabled()
                    .sheet(isPresented: $isQrCodeScannerPresented) {
                        ScannerView(isPresented: $isQrCodeScannerPresented, alarmId: $currentAlarmId, codeType: .qr)
                            .interactiveDismissDisabled()
                    }
            }
        case .tutorial:
            if studyDataVM.isParticipantIdRequired() {
                ParticipantIdView()
            } else {
                TutorialView()
            }
        case .studyOngoing:
            OngoingStudyView()
        }
    }

}

#Preview {
    let permissionDataVM = PermissionDataViewModel()
    let sessionVM = SessionViewModel()
    sessionVM.startStudy()
    let sessionDataVM = StudyDataViewModel()
    
    permissionDataVM.permissionData = permissionDataVM.permissionData.setCameraPermission(isGranted: true)
    permissionDataVM.permissionData = permissionDataVM.permissionData.setNotificationPermission(isGranted: true)
    return MainView().environmentObject(permissionDataVM).environmentObject(sessionVM).environmentObject(sessionDataVM).environmentObject(AppDelegate())
}
