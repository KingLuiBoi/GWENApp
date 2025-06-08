import SwiftUI

struct TimeCapsuleListView: View {
    @StateObject private var viewModel = TimeCapsuleViewModel()
    @State private var showingAddSheet = false

    // Date formatter for displaying open dates
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading && viewModel.timeCapsules.isEmpty {
                    ProgressView("Loading Time Capsules...")
                        .padding()
                } else if let errorMessage = viewModel.errorMessage, !viewModel.timeCapsules.isEmpty {
                    // Show error at top if list is already populated
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                }

                if viewModel.timeCapsules.isEmpty && !viewModel.isLoading {
                    if let errorMessage = viewModel.errorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                            .padding()
                        Button("Retry") {
                            viewModel.fetchTimeCapsules()
                        }
                    } else {
                        Text("No time capsules yet. Tap '+' to create one!")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                } else {
                    List {
                        ForEach(viewModel.timeCapsules) { capsule in
                            VStack(alignment: .leading) {
                                Text(capsule.note)
                                    .font(.headline)
                                Text("Opens: \(capsule.targetDate, formatter: dateFormatter)") // Use targetDate (was openDate)
                                    .font(.subheadline)
                                    .foregroundColor(capsule.targetDate > Date() ? .gray : .blue) // Highlight if openable
                                Text("Created: \(capsule.createdDate, style: .date)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: viewModel.deleteTimeCapsule)
                    }
                }
            }
            .navigationTitle("Time Capsules")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.isLoading && !viewModel.timeCapsules.isEmpty { // Show spinner only if loading more
                        ProgressView()
                    } else {
                        Button {
                            viewModel.fetchTimeCapsules()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Reset for new entry form
                        viewModel.newCapsuleNote = ""
                        viewModel.newCapsuleOpenDate = Date().addingTimeInterval(60*60*24) // Default to 1 day from now
                        viewModel.errorMessage = nil
                        viewModel.addCapsuleSuccess = false
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddTimeCapsuleView()
                    .environmentObject(viewModel) // Pass the viewModel to the sheet
            }
            .onAppear {
                if viewModel.timeCapsules.isEmpty { // Fetch only if list is empty on first appear
                    viewModel.fetchTimeCapsules()
                }
            }
        }
    }
}

struct TimeCapsuleListView_Previews: PreviewProvider {
    static var previews: some View {
        TimeCapsuleListView()
    }
}
