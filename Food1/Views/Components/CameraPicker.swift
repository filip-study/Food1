//
//  CameraPicker.swift
//  Food1
//
//  Created by Claude on 2025-11-04.
//

import SwiftUI
import PhotosUI

/// SwiftUI wrapper for camera and photo library access
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    let sourceType: UIImagePickerController.SourceType
    let onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Source selection sheet for choosing between camera and photo library
struct PhotoSourcePicker: View {
    @Environment(\.dismiss) var dismiss
    let onSourceSelected: (UIImagePickerController.SourceType) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button(action: {
                    onSourceSelected(.camera)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Take Photo")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Use your camera")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Button(action: {
                    onSourceSelected(.photoLibrary)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Choose from Library")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Select an existing photo")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}
