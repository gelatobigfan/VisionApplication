//
//  ContentView.swift
//  YoloDemo
//
//  Created by Clara on 1/4/2025.
//

import SwiftUI
import CoreML
import Vision

struct ContentView: View {
    @State private var predictionText = "Tap the button to detect objects."
    @State private var boxes: [PredictionBox] = []
    @State private var imageSize: CGSize = .zero

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                GeometryReader { geo in
                    Image("testImage")
                        .resizable()
                        .scaledToFit()
                        .background(
                            GeometryReader { imgGeo in
                                Color.clear
                                    .onAppear {
                                        imageSize = imgGeo.size
                                    }
                            }
                        )
                        .overlay(
                            ZStack {
                                ForEach(boxes) { box in
                                    let rect = convertToCGRect(box.boundingBox, in: imageSize)

                                    Rectangle()
                                        .stroke(Color.red, lineWidth: 2)
                                        .frame(width: rect.width, height: rect.height)
                                        .position(x: rect.midX, y: rect.midY)

                                    Text("\(box.label) \(String(format: "%.2f", box.confidence))")
                                        .font(.caption2)
                                        .padding(2)
                                        .background(Color.black.opacity(0.6))
                                        .foregroundColor(.white)
                                        .position(x: rect.minX + 4, y: rect.minY - 10)
                                }
                            }
                        )
                }
                .frame(height: 300)
            }

            Button("Run YOLOv3Tiny") {
                runObjectDetection()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())

            Text(predictionText)
                .padding()
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // Perform object detection using YOLOv3Tiny
    func runObjectDetection() {
        guard let uiImage = UIImage(named: "testImage"),
              let cgImage = uiImage.cgImage else {
            predictionText = "❌ Failed to load image."
            boxes = []
            return
        }

        guard let model = try? YOLOv3Tiny(configuration: MLModelConfiguration()).model,
              let visionModel = try? VNCoreMLModel(for: model) else {
            predictionText = "❌ Failed to load model."
            boxes = []
            return
        }
        
        // Create Vision request
        let request = VNCoreMLRequest(model: visionModel) { request, _ in
            if let results = request.results as? [VNRecognizedObjectObservation], !results.isEmpty {
                var output = "✅ Detected:\n"
                var tempBoxes: [PredictionBox] = []

                for obs in results {
                    if let topLabel = obs.labels.first {
                        let label = topLabel.identifier
                        let confidence = topLabel.confidence
                        output += "- \(label) | Confidence: \(String(format: "%.2f", confidence))\n"

                        let newBox = PredictionBox(label: label, confidence: confidence, boundingBox: obs.boundingBox)
                        tempBoxes.append(newBox)
                    }
                }

                predictionText = output
                boxes = tempBoxes
                print("🔎 Detection results:\n\(output)")
            } else {
                predictionText = "❌ No objects detected."
                boxes = []
            }
        }

        request.imageCropAndScaleOption = .scaleFill
        
        // Run Vision request
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try? handler.perform([request])
    }
}

// Present detection result
struct PredictionBox: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect // normalized
}

func convertToCGRect(_ rect: CGRect, in size: CGSize) -> CGRect {
    return CGRect(
        x: rect.origin.x * size.width,
        y: (1 - rect.origin.y - rect.height) * size.height,
        width: rect.width * size.width,
        height: rect.height * size.height
    )
}

#Preview {
    ContentView()
}
