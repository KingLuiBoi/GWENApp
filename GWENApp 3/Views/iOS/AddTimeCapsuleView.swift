import SwiftUI

struct AddTimeCapsuleView: View {
    @EnvironmentObject var viewModel: TimeCapsuleViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Time Capsule Note")) {
                    TextEditor(text: $viewModel.newCapsuleNote)
                        .frame(height: 200)
                        .border(Color.gray.opacity(0.2), width: 1) // Optional: visual cue for TextEditor
                }

                Section(header: Text("Open Date")) {
                    DatePicker(
                        "Select Date",
                        selection: $viewModel.newCapsuleOpenDate,
                        in: Date()..., // Allow selection from today onwards
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
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
                            } else {
                                Text("Save Time Capsule")
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.newCapsuleNote.isEmpty)
                }
            }
            .navigationTitle("Add Time Capsule")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Clear any previous error messages and reset success flag
                viewModel.errorMessage = nil
                viewModel.addCapsuleSuccess = false
            }
            .onChange(of: viewModel.addCapsuleSuccess) { success in
                if success {
                    dismiss()
                }
            }
        }
    }
}

struct AddTimeCapsuleView_Previews: PreviewProvider {
    static var previews: some View {
        AddTimeCapsuleView()
            .environmentObject(TimeCapsuleViewModel()) // Provide a dummy ViewModel for preview
    }
}
