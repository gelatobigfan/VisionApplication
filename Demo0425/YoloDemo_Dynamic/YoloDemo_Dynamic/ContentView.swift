//
//  ContentView.swift
//  YoloDemo_Dynamic
//
//  Created by Tungl on 7/4/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            // Live camera feed
            CameraView()
                .edgesIgnoringSafeArea(.all)

            // Overlay Text (optional)
            VStack {
                Spacer()
                Text("🔍 YOLO Real-Time Detection")
                    .font(.headline)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    ContentView()
}
