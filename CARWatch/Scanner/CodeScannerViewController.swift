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
    private let sessionQueue = DispatchQueue(label: "de.portabiles.carwatch.scanner.session")
    private var isSessionConfigured = false
    
    var codeType: ScannerConstants.CodeType
    var codeWidthHeightRatio: CGFloat
    
    public init(parentView: CodeScanner!, cameraView: AVCaptureVideoPreviewLayer? = nil, codeType: ScannerConstants.CodeType, codeWidthHeightRatio: CGFloat) {
        self.parentView = parentView
        self.cameraView = cameraView
        self.codeType = codeType
        self.codeWidthHeightRatio = codeWidthHeightRatio
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.codeType = ScannerConstants.CodeType.ean8
        self.codeWidthHeightRatio = ScannerConstants.defaultWidthHeightRatio
        super.init(coder: coder)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupSession()
    }
    
    private func setupSession() {
        if cameraView == nil {
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.layer.bounds
            view.layer.addSublayer(previewLayer)
            cameraView = previewLayer
        } else {
            cameraView?.frame = view.layer.bounds
        }

        sessionQueue.async {
            if !self.isSessionConfigured {
                self.captureSession.beginConfiguration()
                defer {
                    self.captureSession.commitConfiguration()
                }

                guard let captureDevice = AVCaptureDevice.default(for: .video) else {
                    DispatchQueue.main.async {
                        self.parentView.completion(.failure(.badInput))
                    }
                    return
                }

                let videoDeviceInput: AVCaptureDeviceInput
                do {
                    videoDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
                } catch {
                    DispatchQueue.main.async {
                        self.parentView.completion(.failure(.initError(error)))
                    }
                    return
                }

                if self.captureSession.canAddInput(videoDeviceInput) {
                    self.captureSession.addInput(videoDeviceInput)
                } else {
                    DispatchQueue.main.async {
                        self.parentView.completion(.failure(.badInput))
                    }
                    return
                }

                let metadataOutput = AVCaptureMetadataOutput()
                if self.captureSession.canAddOutput(metadataOutput) {
                    self.captureSession.addOutput(metadataOutput)
                    let supportedCodeTypes = self.codeType == ScannerConstants.CodeType.ean8 ? [AVMetadataObject.ObjectType.ean8] : [AVMetadataObject.ObjectType.qr]
                    metadataOutput.metadataObjectTypes = supportedCodeTypes
                    metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                    DispatchQueue.main.async {
                        self.addRectOfInterest(metadataOutput)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.parentView.completion(.failure(.badOutput))
                    }
                    return
                }

                self.isSessionConfigured = true
            }

            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
        
        Logger.instance.log(tag: LoggerConstants.loggerActionBarcodeScanInit, message:[String: Any]())
    }
    
    private func addRectOfInterest(_ metadataOutput: AVCaptureMetadataOutput) {
        let barcodeArea = calculateScannerRectOfInterest(width:  view.frame.size.width, height:  view.frame.size.height, widthHeightRatio: codeWidthHeightRatio)
        metadataOutput.rectOfInterest = cameraView!.metadataOutputRectConverted(fromLayerRect: barcodeArea)
        
        let barcodeAreaView = UIView()
        // uncomment the next two lines for debugging viewfinder
        // barcodeAreaView.layer.borderColor = UIColor.red.cgColor
        // barcodeAreaView.layer.borderWidth = 2
        barcodeAreaView.frame = barcodeArea
        view.addSubview(barcodeAreaView)
        view.bringSubviewToFront(barcodeAreaView)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        super.viewWillDisappear(animated)
        
        // Stop AV capture session
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            parentView.completion(.failure(.badOutput))
            return
        }
        
        // check if scanning result is valid
        if !parentView.validation(stringValue) {
            return
        }
        
        // Vibration on successful scan
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        // Stop AV capture session
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
        parentView.completion(.success(stringValue))
    }
}

func calculateScannerRectOfInterest(width: CGFloat, height: CGFloat, widthHeightRatio: CGFloat) -> CGRect {
    let rectWidth = width / ScannerConstants.overlayWidthFactor;
    let rectHeight = rectWidth / widthHeightRatio;
    let xPos = (width - rectWidth) / 2.0
    let yPos = (height - rectHeight) / 2.0
    return CGRect(x: xPos, y: yPos, width: rectWidth, height: rectHeight)
}
