//
//  GwenChatView.swift
//  GWENApp
//
//  Created by Manus on 5/14/25.
//

import SwiftUI

struct GwenChatView: View {
    @StateObject private var viewModel = GwenChatViewModel()
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Conversation History
                ScrollViewReader { scrollViewProxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.conversation, id: \.id) { interaction in
                                ChatBubbleView(interaction: interaction, viewModel: viewModel)
                                    .id(interaction.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.conversation.count) {
                        // Auto-scroll to the bottom when new messages are added
                        if let lastInteraction = viewModel.conversation.last {
                            withAnimation {
                                scrollViewProxy.scrollTo(lastInteraction.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Error Message Display
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                // Thinking Indicator
                if viewModel.isThinking {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 5)
                        Text("GWEN is thinking...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                // Input Area
                HStack(spacing: 12) {
                    // Text Input Field
                    TextField("Ask GWEN...", text: $viewModel.currentInput, onCommit: {
                        viewModel.sendCurrentPrompt()
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    
                    // Send Button (if text input is not empty)
                    if !viewModel.currentInput.isEmpty {
                        Button(action: {
                            viewModel.sendCurrentPrompt()
                            isTextFieldFocused = false
                        }) {
                            Image(systemName: "paperplane.fill")
                                .font(.title2)
                        }
                    }
                    
                    // Microphone Button (for active listening)
                    Button(action: {
                        if viewModel.isActivelyListening {
                            viewModel.stopActiveListening()
                        } else {
                            viewModel.startActiveListening()
                        }
                    }) {
                        Image(systemName: viewModel.isActivelyListening ? "mic.fill" : "mic.slash.fill")
                            .font(.title2)
                            .foregroundColor(viewModel.isActivelyListening ? .red : .blue)
                    }
                }
                .padding()
                .background(.thinMaterial) // Adapts to light/dark mode
            }
            .navigationTitle("GWEN")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        viewModel.toggleHeyGwenListening()
                    }) {
                        Image(systemName: viewModel.isListeningForHeyGwen ? "ear.and_waveform" : "ear")
                            .foregroundColor(viewModel.isListeningForHeyGwen ? .green : .gray)
                    }
                    .help(viewModel.isListeningForHeyGwen ? "Stop listening for \"Hey GWEN\"" : "Listen for \"Hey GWEN\"")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.hasPermissions {
                        Button("Permissions") {
                            viewModel.requestVoicePermissions()
                        }
                    }
                }
            }
            .onAppear {
                // Request permissions when the view appears if not already granted
                viewModel.requestVoicePermissions() // Ensures permissions are checked/requested early
                viewModel.startHeyGwenIfNeeded() // Attempt to start "Hey GWEN" listening
            }
        }
    }
}

struct ChatBubbleView: View {
    let interaction: GwenInteraction
    @ObservedObject var viewModel: GwenChatViewModel // To call playAudio

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // User Prompt
            HStack {
                Spacer()
                Text(interaction.userPrompt)
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .padding(.leading, 40)

            // GWEN Response (Transcript and Audio)
            // For now, we don_t have a separate GWEN transcript from backend, so we just show a placeholder if audio exists
            if interaction.audioData != nil || interaction.gwenTranscript != nil {
                HStack {
                    VStack(alignment: .leading) {
                        if let transcript = interaction.gwenTranscript {
                            Text(transcript)
                                .padding(.bottom, 2)
                        } else {
                            Text("(GWEN responded with audio)")
                                .font(.caption)
                                .italic()
                        }
                        if interaction.audioData != nil {
                            Button(action: {
                                viewModel.playAudio(for: interaction.id)
                            }) {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("Play GWENs Response")
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    Spacer()
                }
                .padding(.trailing, 40)
            }
        }
    }
}

#Preview {
    GwenChatView()
}

