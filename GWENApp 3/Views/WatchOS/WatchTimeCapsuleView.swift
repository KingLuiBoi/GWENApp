//
//  WatchTimeCapsuleView.swift
//  GWENAppWatchOS
//
//  Created by Manus on 5/14/25.
//

import SwiftUI

struct WatchTimeCapsuleView: View {
    // Using the iOS TimeCapsuleViewModel for now. 
    // A dedicated WatchOS ViewModel might be needed for more tailored logic.
    @StateObject private var viewModel = TimeCapsuleViewModel() 
    @State private var showingAddSheet = false
    @State private var newEntryText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Time Capsule")
                        .font(.headline)
                    Spacer()
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom, 5)

                if viewModel.isLoading && viewModel.entries.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Button("Retry Fetch") {
                        viewModel.fetchEntries()
                    }
                    .font(.caption)
                } else if viewModel.entries.isEmpty {
                    Text("No entries yet. Tap + to add.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top)
                } else {
                    // Display a few recent entries
                    ForEach(viewModel.entries.prefix(3)) { entry in // Show max 3 for watch
                        VStack(alignment: .leading) {
                            Text(entry.note)
                                .font(.system(.caption, design: .rounded))
                                .lineLimit(2)
                            if let tag = entry.tag, !tag.isEmpty {
                                Text("Tag: \(tag)")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            Text(entry.displayDate)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 3)
                        Divider()
                    }
                    if viewModel.entries.count > 3 {
                        Text("View all on iPhone...") // Placeholder for deeper navigation or more items
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Capsule") // Often not visible in root of TabView page style
        .onAppear {
            // Backend doesn_t have GET /timecapsules yet, so this will show a warning.
            if viewModel.entries.isEmpty {
                viewModel.fetchEntries()
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            WatchAddTimeCapsuleView(viewModel: viewModel)
        }
    }
}

struct WatchAddTimeCapsuleView: View {
    @ObservedObject var viewModel: TimeCapsuleViewModel // Passed from parent
    @Environment(\.dismiss) var dismiss
    @State private var noteInput: String = ""
    // Tags might be omitted or simplified for WatchOS

    var body: some View {
        VStack(spacing: 15) {
            Text("New Capsule Entry")
                .font(.headline)
            
            // For WatchOS, direct text input is cumbersome.
            // Voice input would be ideal here.
            // Placeholder for text input or voice input trigger
            TextField("Type or dictate note...", text: $noteInput)
                .textFieldStyle(.roundedBorder)
                .frame(height: 80) // Allow some space for multiline
            
            // Or a button to trigger voice input for the note
            Button(action: {
                // TODO: Integrate with VoiceInputService to get note text
                // For now, we_ll use the TextField content.
                print("Voice input for note tapped - (not implemented yet)")
                // If voice input populates noteInput, then save can proceed.
            }) {
                Image(systemName: "mic.fill")
                Text("Dictate Note")
            }

            Button("Save Entry") {
                if !noteInput.isEmpty {
                    viewModel.newEntryNote = noteInput // Set it on the shared ViewModel
                    viewModel.newEntryTag = "" // No tag input for watch simplicity for now
                    viewModel.addEntry()
                    // Dismissal logic is in the iOS version_s AddTimeCapsuleView onChange of entries.count
                    // We can replicate or simplify here.
                    // For now, assume addEntry will eventually lead to list update and potential auto-dismissal
                    // or user manually dismisses.
                    dismiss()
                } else {
                    // Show some error or disable button
                }
            }
            .disabled(noteInput.isEmpty || viewModel.isLoading)
            .buttonStyle(.borderedProminent)
            
            if viewModel.isLoading {
                ProgressView()
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .onAppear { viewModel.errorMessage = nil }
    }
}

#Preview {
    WatchTimeCapsuleView()
}

