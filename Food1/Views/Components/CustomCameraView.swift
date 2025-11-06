//
//  CustomCameraView.swift
//  Food1
//
//  Created by Claude on 2025-11-07.
//

import SwiftUI
import AVFoundation
import UIKit
import Combine

/// Custom camera view with live preview and quick access to gallery/manual entry
struct CustomCameraView: View {
    @Environment(\.dismiss) var dismiss

    let selectedDate: Date
    let onPhotoCaptured: (UIImage) -> Void
    let onGalleryTap: () -> Void
    let onManualTap: () -> Void

    @StateObject private var cameraManager = CameraManager()
    @State private var showingPermissionAlert = false
    @State private var captureAnimation = false

    var body: some View {
        ZStack {
            // Camera preview
            if cameraManager.isAuthorized {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()

                // Focus rectangle overlay
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
                        .frame(
                            width: geometry.size.width * 0.75,
                            height: geometry.size.width * 0.75
                        )
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height / 2.2
                        )
                }
                .ignoresSafeArea()

                // Flash animation overlay
                if captureAnimation {
                    Color.white
                        .ignoresSafeArea()
                        .opacity(captureAnimation ? 0.8 : 0)
                        .animation(.easeOut(duration: 0.2), value: captureAnimation)
                }

                // Overlay UI
                VStack {
                    // Top bar
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }

                        Spacer()

                        // Flash toggle
                        Button(action: {
                            cameraManager.toggleFlash()
                        }) {
                            Image(systemName: cameraManager.flashMode == .on ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(cameraManager.flashMode == .on ? .yellow : .white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Spacer()

                    // Bottom controls
                    VStack(spacing: 24) {
                        // Instructions
                        VStack(spacing: 8) {
                            Text("Center your food in the frame")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Text("Make sure it's well lit and in focus")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.6))
                        )

                        // Action buttons
                        HStack(spacing: 40) {
                            // Gallery button
                            Button(action: {
                                onGalleryTap()
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 56, height: 56)
                                        .background(Circle().fill(Color.black.opacity(0.5)))

                                    Text("Gallery")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }

                            // Capture button (center, larger)
                            Button(action: {
                                capturePhoto()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 76, height: 76)

                                    Circle()
                                        .stroke(Color.white, lineWidth: 4)
                                        .frame(width: 88, height: 88)
                                }
                            }
                            .scaleEffect(captureAnimation ? 0.9 : 1.0)

                            // Manual button
                            Button(action: {
                                onManualTap()
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "keyboard")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 56, height: 56)
                                        .background(Circle().fill(Color.black.opacity(0.5)))

                                    Text("Manual")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            } else if cameraManager.permissionDenied {
                // Permission denied state
                permissionDeniedView
            } else {
                // Loading state
                loadingView
            }
        }
        .background(Color.black)
        .onAppear {
            cameraManager.checkAuthorization()
        }
        .alert("Camera Access Required", isPresented: $showingPermissionAlert) {
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Food1 needs access to your camera to recognize food. Please enable camera access in Settings.")
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Initializing camera...")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.7))

            VStack(spacing: 12) {
                Text("Camera Access Required")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text("Food1 needs camera access to recognize food and log meals automatically.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Open Settings")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(12)
                }

                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Actions

    private func capturePhoto() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Flash animation
        withAnimation {
            captureAnimation = true
        }

        // Capture photo
        cameraManager.capturePhoto { image in
            if let image = image {
                onPhotoCaptured(image)
            }

            // Reset animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                captureAnimation = false
            }
        }
    }
}

// MARK: - Camera Manager

class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var permissionDenied = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off

    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage?) -> Void)?

    override init() {
        super.init()
    }

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.permissionDenied = true
            }
        @unknown default:
            permissionDenied = true
        }
    }

    private func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            session.commitConfiguration()
            return
        }

        session.addInput(videoInput)

        // Add photo output
        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return
        }

        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality

        session.commitConfiguration()

        // Start session on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()

            DispatchQueue.main.async {
                self?.isAuthorized = true
            }
        }
    }

    func toggleFlash() {
        flashMode = flashMode == .off ? .on : .off
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.captureCompletion = completion

        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    deinit {
        session.stopRunning()
    }
}

// MARK: - Photo Capture Delegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            captureCompletion?(nil)
            return
        }

        captureCompletion?(image)
        captureCompletion = nil
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
