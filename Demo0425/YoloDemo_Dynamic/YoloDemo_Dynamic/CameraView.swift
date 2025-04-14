import SwiftUI
import AVFoundation
import CoreML
import Vision

struct CameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> some UIViewController {
        return CameraPreviewController()
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
}

class CameraPreviewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var visionModel: VNCoreMLModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupModel()
        setupCamera()
    }

    /// Load YOLOv3Tiny CoreML model and wrap for Vision
    private func setupModel() {
        do {
            let model = try YOLOv3Tiny(configuration: MLModelConfiguration()).model
            visionModel = try VNCoreMLModel(for: model)
        } catch {
            print("❌ Failed to load YOLO model: \(error)")
        }
    }

    /// Setup camera input and frame capture
    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            print("❌ Failed to access camera.")
            return
        }

        session.addInput(input)

        // Preview layer
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        // Setup frame output
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        session.addOutput(output)

        session.startRunning()
        captureSession = session
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    /// Called for every camera frame
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let visionModel = visionModel else {
            return
        }

        let request = VNCoreMLRequest(model: visionModel) { request, _ in
            if let results = request.results as? [VNRecognizedObjectObservation], !results.isEmpty {
                let topLabels = results.prefix(3).compactMap { obs in
                    obs.labels.first.map { "\($0.identifier) (\(String(format: "%.2f", $0.confidence)))" }
                }
                print("✅ Detected: \(topLabels.joined(separator: ", "))")
            }
        }

        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }
}
