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
    private let overlayLayer = CALayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupModel()
        setupCamera()
    }

    private func setupModel() {
        do {
            let model = try YOLOv3Tiny(configuration: MLModelConfiguration()).model
            visionModel = try VNCoreMLModel(for: model)
        } catch {
            print("❌ Failed to load YOLO model: \(error)")
        }
    }

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

        // Overlay layer
        overlayLayer.frame = view.bounds
        view.layer.addSublayer(overlayLayer)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        session.addOutput(output)

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        captureSession = session
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        overlayLayer.frame = view.bounds
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let visionModel = visionModel else {
            return
        }

        let request = VNCoreMLRequest(model: visionModel) { request, _ in
            guard let results = request.results as? [VNRecognizedObjectObservation] else { return }

            // Print detection labels to console
            let topLabels = results.prefix(3).compactMap { obs in
                obs.labels.first.map { "\($0.identifier) (\(String(format: "%.2f", $0.confidence)))" }
            }
            if !topLabels.isEmpty {
                print("✅ Detected: \(topLabels.joined(separator: ", "))")
            }

            // Draw overlays
            DispatchQueue.main.async {
                self.overlayLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

                for observation in results {
                    guard let label = observation.labels.first else { continue }

                    let rect = self.convert(boundingBox: observation.boundingBox)

                    // Rectangle
                    let boxLayer = CALayer()
                    boxLayer.frame = rect
                    boxLayer.borderColor = UIColor.red.cgColor
                    boxLayer.borderWidth = 2
                    self.overlayLayer.addSublayer(boxLayer)

                    // Text
                    let textLayer = CATextLayer()
                    textLayer.string = "\(label.identifier) (\(String(format: "%.2f", label.confidence)))"
                    textLayer.fontSize = 12
                    textLayer.foregroundColor = UIColor.white.cgColor
                    textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
                    textLayer.alignmentMode = .center
                    textLayer.cornerRadius = 4
                    textLayer.masksToBounds = true
                    textLayer.frame = CGRect(x: rect.origin.x,
                                             y: max(rect.origin.y - 18, 0),
                                             width: rect.width,
                                             height: 18)
                    self.overlayLayer.addSublayer(textLayer)
                }
            }
        }

        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }

    private func convert(boundingBox: CGRect) -> CGRect {
        let width = view.bounds.width
        let height = view.bounds.height

        let x = boundingBox.origin.x * width
        let y = (1 - boundingBox.origin.y - boundingBox.height) * height
        let w = boundingBox.width * width
        let h = boundingBox.height * height

        return CGRect(x: x, y: y, width: w, height: h)
    }
}
