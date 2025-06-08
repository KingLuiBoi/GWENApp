//
//  TimeCapsuleListView.swift
//  GWENApp
//
//  Created by Manus on 5/14/25.
//

import SwiftUI

struct TimeCapsuleListView: View {
    @StateObject private var viewModel = TimeCapsuleViewModel()
    @State private var showingAddSheet = false

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading && viewModel.entries.isEmpty {
                    ProgressView("Loading Entries...")
                } else if let errorMessage = viewModel.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                    Button("Retry") {
                        viewModel.fetchEntries()
                    }
                } else if viewModel.entries.isEmpty {
                    Text("No time capsule entries yet. Tap + to add one!")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(viewModel.entries) { entry in
                            TimeCapsuleRow(entry: entry)
                        }
                    }
                }
            }
            .navigationTitle("Time Capsule")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button {
                            viewModel.fetchEntries() // Manual refresh
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddTimeCapsuleView()
                    .environmentObject(viewModel) // Pass the same VM instance
            }
            .onAppear {
                // Fetch entries when the view appears, if not already loaded
                // The backend currently doesn_t have a GET /timecapsules endpoint in the provided script
                // So, fetchEntries() will print a warning and return an empty array.
                // This UI is built assuming the endpoint could be added later.
                if viewModel.entries.isEmpty {
                     viewModel.fetchEntries()
                }
            }
        }
    }
}

struct TimeCapsuleRow: View {
    let entry: TimeCapsuleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.note)
                .font(.headline)
            if let tag = entry.tag, !tag.isEmpty {
                Text("Tag: \(tag)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            Text("Saved: \(entry.displayDate)")
                .font(.footnote)
                .foregroundColor(.gray)
            if let audioFilename = entry.audioFilename, !audioFilename.isEmpty {
                // Placeholder for audio playback UI for the capsule entry
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                    Text("Audio available (\[audioFilename])")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddTimeCapsuleView: View {
    @EnvironmentObject var viewModel: TimeCapsuleViewModel // Use shared VM
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Time Capsule Entry")) {
                    TextField("Note (required)", text: $viewModel.newEntryNote, axis: .vertical)
                        .lineLimit(5...)
                    TextField("Tag (optional)", text: $viewModel.newEntryTag)
                }

                Section {
                    Button(action: {
                        viewModel.addEntry()
                        // Dismissal should ideally happen upon successful addition
                        // For now, we dismiss immediately. ViewModel could publish a success state.
                        // Consider observing isLoading or a dedicated success publisher.
                        // If addEntry becomes async and updates a published property on success,
                        // we can use .onChange to dismiss.
                        // For now, simple dismiss:
                        // dismiss()
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Save Entry")
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.newEntryNote.isEmpty || viewModel.isLoading)
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Entry")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            // Clear error when view appears/disappears or when input changes
            .onAppear { viewModel.errorMessage = nil }
            .onChange(of: viewModel.entries.count) { _, _ in // Crude way to detect successful add
                if !viewModel.isLoading { // Ensure it's not still loading from a previous attempt
                    dismiss() // Dismiss if entry count changed (likely due to successful add)
                }
            }
        }
    }
}

#Preview {
    TimeCapsuleListView()
}

