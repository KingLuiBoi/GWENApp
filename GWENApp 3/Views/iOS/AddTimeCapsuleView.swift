import SwiftUI

struct AddTimeCapsuleView: View {
    @EnvironmentObject var viewModel: TimeCapsuleViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("New Time Capsule Note") {
                    TextEditor(text: $viewModel.newCapsuleNote)
                        .frame(minHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }

                Section("Open Date") {
                    DatePicker(
                        "Select Date",
                        selection: $viewModel.newCapsuleOpenDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                }
                
                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button(action: {
                        viewModel.addTimeCapsule()
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Save Time Capsule")
                                    .fontWeight(.medium)
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.newCapsuleNote.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Add Time Capsule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.errorMessage = nil
                viewModel.addCapsuleSuccess = false
            }
            .onChange(of: viewModel.addCapsuleSuccess) { _, success in
                if success {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    AddTimeCapsuleView()
        .environmentObject(TimeCapsuleViewModel())
}

