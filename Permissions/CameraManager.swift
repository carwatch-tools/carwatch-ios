import Foundation
import AVFoundation

class CameraManager : ObservableObject {
    static let instance = CameraManager() // Singleton
    var permissionGranted = false
    
    func reloadCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        self.permissionGranted = status == .authorized ? true : false
        print("permission status reloaded: \(self.permissionGranted)")
    }
    
    func requestPermission(completion: @escaping (Bool) -> ()) {
        AVCaptureDevice.requestAccess(for: .video) { accessGranted in
            DispatchQueue.main.async {
                self.permissionGranted = accessGranted
                completion(true)
            }
        }
    }
}
