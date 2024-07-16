import AVFoundation
import SwiftUI

public enum ScanError: Error {
    /// The camera could not be accessed.
    case badInput
    
    /// The camera was not capable of scanning the requested codes.
    case badOutput
    
    /// Initialization failed.
    case initError(_ error: Error)
}

class CodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    // Parent view required for completion function
    var parentView: CodeScanner!
    // Camera view
    var cameraView: AVCaptureVideoPreviewLayer?
    // AV capture session and dispatch queue
    let captureSession = AVCaptureSession()
    let sessionQueue = DispatchQueue(label: AVCaptureSession.self.description(), attributes: [], target: nil)
    
    // Active Viewfinder
    var barcodeAreaView: UIView?
    var barcodeArea: CGRect
    var barcodeAreaWidth: CGFloat = 0
    var barcodeAreaHeight: CGFloat = 0
    var barcodeAreaXPos: CGFloat = 0
    var barcodeAreaYPos: CGFloat = 0
    
    var codeType: ScannerConstants.CodeType = ScannerConstants.CodeType.ean8
    let metadataOutput = AVCaptureMetadataOutput()
    
    public init(parentView: CodeScanner!, cameraView: AVCaptureVideoPreviewLayer? = nil, barcodeAreaView: UIView? = nil, codeType: ScannerConstants.CodeType, barcodeAreaWidth: CGFloat, barcodeAreaHeight: CGFloat, barcodeAreaXPos: CGFloat, barcodeAreaYPos: CGFloat) {
        self.parentView = parentView
        self.cameraView = cameraView
        self.codeType = codeType
        self.barcodeAreaView = barcodeAreaView
        self.barcodeAreaWidth = barcodeAreaWidth
        self.barcodeAreaHeight = barcodeAreaHeight
        self.barcodeAreaXPos = barcodeAreaXPos
        self.barcodeAreaYPos = barcodeAreaYPos
        self.barcodeArea = CGRect(x: barcodeAreaXPos, y: barcodeAreaYPos, width: barcodeAreaWidth, height: barcodeAreaHeight)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.barcodeArea = CGRect(x: barcodeAreaXPos, y: barcodeAreaYPos, width: barcodeAreaWidth, height: barcodeAreaHeight)
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        barcodeAreaView = UIView()
        // uncomment the next two lines for debugging viewfinder
        barcodeAreaView?.layer.borderColor = UIColor.red.cgColor
        barcodeAreaView?.layer.borderWidth = 1
        barcodeAreaView?.frame = barcodeArea
        view.addSubview(barcodeAreaView!)
        
        captureSession.beginConfiguration()
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            parentView.completion(.failure(.badInput))
            return
        }
        
        let videoDeviceInput: AVCaptureDeviceInput
        
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
        } catch {
            parentView.completion(.failure(.initError(error)))
            return
        }
        
        if captureSession.canAddInput(videoDeviceInput) {
            captureSession.addInput(videoDeviceInput)
        }
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            let supportedCodeTypes = codeType == ScannerConstants.CodeType.ean8 ? [ AVMetadataObject.ObjectType.ean8] : [ AVMetadataObject.ObjectType.qr]
            metadataOutput.metadataObjectTypes = supportedCodeTypes
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            
            cameraView = AVCaptureVideoPreviewLayer(session: captureSession)
            cameraView?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            cameraView?.frame = view.layer.bounds
            
            metadataOutput.rectOfInterest = cameraView!.metadataOutputRectConverted(fromLayerRect: barcodeArea)
            view.layer.addSublayer(cameraView!)
        }
        
        captureSession.commitConfiguration()
        view.bringSubviewToFront(barcodeAreaView!)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        // Start AV capture session
        sessionQueue.async {
            self.captureSession.startRunning()
            self.metadataOutput.rectOfInterest = self.cameraView!.metadataOutputRectConverted(fromLayerRect: self.barcodeArea)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        super.viewWillDisappear(animated)
        
        // Stop AV capture session
        sessionQueue.async {
            self.captureSession.stopRunning()
        }
    }
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        print("capturing output ")
        
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            parentView.completion(.failure(.badOutput))
            return
        }
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        print(stringValue)
        parentView.completion(.success(stringValue))
    }
}

