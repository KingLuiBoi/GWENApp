//
//  WatchGwenChatView.swift
//  GWENAppWatchOS
//
//  Created by Manus on 5/14/25.
//

import SwiftUI

struct WatchGwenChatView: View {
    @StateObject private var viewModel = WatchGwenChatViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if !viewModel.hasPermissions {
                    Button("Grant Permissions") {
                        viewModel.requestVoicePermissions()
                    }
                    .padding()
                    Text("Voice and Mic permissions needed.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                
                // Action Button (Mic / Hey GWEN toggle)
                Button(action: {
                    if viewModel.isActivelyListening {
                        viewModel.stopActiveListening()
                    } else if viewModel.isListeningForHeyGwen {
                        viewModel.toggleHeyGwenListening() // Stop Hey GWEN
                    } else {
                        // Default to tap-to-speak if not already listening for Hey GWEN
                        viewModel.startActiveListening()
                    }
                }) {
                    VStack {
                        if viewModel.isActivelyListening {
                            Image(systemName: "stop.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .foregroundColor(.red)
                            Text("Stop")
                                .font(.caption)
                        } else if viewModel.isListeningForHeyGwen {
                             Image(systemName: "ear.and_waveform")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .foregroundColor(.green)
                            Text("Listening...")
                                .font(.caption)
                        } else {
                            Image(systemName: "mic.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .foregroundColor(.blue)
                            Text("Tap to Speak")
                                .font(.caption)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle()) // Use plain style for better custom appearance
                .padding(.bottom)
                
                // Status / Interaction Display
                if viewModel.isThinking {
                    ProgressView()
                    Text("GWEN is thinking...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else if viewModel.isGwenSpeaking {
                    HStack {
                         Image(systemName: "speaker.wave.2.fill")
                         Text("GWEN Speaking...")
                    }
                    .font(.footnote)
                    .foregroundColor(.accentColor)
                }

                if let userPrompt = viewModel.lastUserPrompt {
                    Text("You: \(userPrompt)")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                if let gwenResponse = viewModel.lastGwenResponse {
                    Text("GWEN: \(gwenResponse)")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // Optional: Toggle for "Hey GWEN" - less ideal for watch battery
                // Consider removing if tap-to-speak is preferred primary interaction
                Button(action: {
                    viewModel.toggleHeyGwenListening()
                }) {
                    Text(viewModel.isListeningForHeyGwen ? "Stop \"Hey GWEN\"" : "Start \"Hey GWEN\"")
                        .font(.caption2)
                }
                .padding(.top)

            }
            .padding()
        }
        .navigationTitle("GWEN") // Often not visible in root of TabView page style
        .onAppear {
            if !viewModel.hasPermissions {
                viewModel.requestVoicePermissions()
            }
        }
    }
}

#Preview {
    WatchGwenChatView()
}

