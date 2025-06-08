//
//  WatchContentView.swift
//  GWENAppWatchOS
//
//  Created by Manus on 5/14/25.
//

import SwiftUI

struct WatchContentView: View {
    var body: some View {
        TabView {
            WatchGwenChatView()
                .tabItem {
                    Label("GWEN", systemImage: "message.fill")
                }

            WatchTimeCapsuleView()
                .tabItem {
                    Label("Capsule", systemImage: "archivebox.fill") // Shorter label for Watch
                }

            WatchRemindersView()
                .tabItem {
                    Label("Reminders", systemImage: "list.bullet.rectangle.fill")
                }

            WatchPlacesView()
                .tabItem {
                    Label("Places", systemImage: "map.fill")
                }
        }
        // .tabViewStyle(.page(indexDisplayMode: .automatic)) // For swipe navigation
        // Note: For watchOS, TabView defaults to page-based navigation if not nested in NavigationView.
        // If direct views are used, this should work as expected for swiping.
    }
}

// MARK: - WatchOS Views

struct WatchGwenChatView: View {
    @StateObject private var viewModel = GwenChatViewModel()
    // Assuming VoiceInputService and AudioPlaybackService are available and functional on watchOS.
    // AudioPlaybackService might need specific handling for watch output.

    var body: some View {
        VStack(spacing: 8) {
            // Status / Transcribed Text Area
            Text(statusText)
                .font(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(height: 30) // Fixed height to prevent layout shifts

            // Conversation History (simplified)
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.conversation.suffix(3)) { interaction in // Show last 3 interactions
                            VStack(alignment: .leading) {
                                Text("You: \(interaction.userPrompt)")
                                    .font(.footnote)
                                    .foregroundColor(.blue)
                                if let gwenTranscript = interaction.gwenTranscript {
                                    Text("GWEN: \(gwenTranscript)")
                                        .font(.footnote)
                                } else if interaction.audioData != nil {
                                    Text("GWEN: (Responded with audio)")
                                        .font(.footnote)
                                        .italic()
                                }
                            }
                            .id(interaction.id)
                            Divider()
                        }
                    }
                }
                .onChange(of: viewModel.conversation.count) {
                    if let lastInteraction = viewModel.conversation.last {
                        withAnimation {
                            scrollViewProxy.scrollTo(lastInteraction.id, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(minHeight: 50) // Ensure it takes some space

            Spacer()

            // "Hey GWEN" Toggle / Listening Button
            Button(action: {
                if viewModel.isActivelyListening { // If actively listening to a command (after "Hey GWEN" or tap)
                    viewModel.stopActiveListening() // This will trigger sendCurrentPrompt if text exists
                } else {
                    viewModel.toggleHeyGwenListening()
                }
            }) {
                Image(systemName: buttonSystemImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .foregroundColor(buttonColor)
            }
            .clipShape(Circle()) // Make button circular
            .padding(.bottom, 5)

            if viewModel.isThinking {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .onAppear {
            viewModel.requestVoicePermissions()
            viewModel.startHeyGwenIfNeeded()
        }
        // .navigationTitle("GWEN") // Usually not shown in page-based TabView items
    }

    private var statusText: String {
        if viewModel.isActivelyListening && !viewModel.isListeningForHeyGwen {
            return viewModel.currentInput.isEmpty ? "Listening..." : viewModel.currentInput
        } else if viewModel.isListeningForHeyGwen {
            return "Say \"Hey GWEN\""
        } else if viewModel.isThinking {
            return "GWEN is thinking..."
        } else if let error = viewModel.errorMessage {
            return error
        } else if let lastResponse = viewModel.conversation.last?.gwenTranscript {
            return lastResponse
        }
        return "Tap mic to start"
    }

    private var buttonSystemImage: String {
        if viewModel.isActivelyListening && !viewModel.isListeningForHeyGwen {
            return "stop.circle.fill" // To stop command recording (and send)
        } else if viewModel.isListeningForHeyGwen {
            return "ear.and_waveform"
        }
        return "mic.slash.fill" // Default: "Hey GWEN" is off
    }

    private var buttonColor: Color {
        if viewModel.isActivelyListening && !viewModel.isListeningForHeyGwen {
            return .red // Stop button
        } else if viewModel.isListeningForHeyGwen {
            return .green
        }
        return .blue // Default: "Hey GWEN" is off
    }
}

struct WatchTimeCapsuleView: View {
    @StateObject private var viewModel = WatchTimeCapsuleViewModel()
    @State private var showingAddSheet = false

    // Optimized DateFormatter
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack {
            if viewModel.isLoading && viewModel.timeCapsules.isEmpty {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            } else if viewModel.timeCapsules.isEmpty {
                Text("No time capsules.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                List {
                    ForEach(viewModel.timeCapsules) { capsule in
                        VStack(alignment: .leading) {
                            Text(capsule.note)
                                .font(.headline)
                                .lineLimit(2)
                            Text("Opens: \(capsule.targetDate, formatter: Self.dateFormatter)") // Use static formatter
                                .font(.caption2)
                                .foregroundColor(capsule.targetDate > Date() ? .gray : .blue) // Highlight if openable
                            Text("Created: \(Date(timeIntervalSince1970: capsule.created_at), style: .relative) ago")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .onDelete(perform: viewModel.deleteTimeCapsule)
                }
            }

            Spacer()

            Button {
                viewModel.newCapsuleNote = ""
                viewModel.newCapsuleOpenDate = Date().addingTimeInterval(60*60*24) // Reset default
                showingAddSheet = true
            } label: {
                Label("New Capsule", systemImage: "plus.circle.fill")
            }
            .padding(.top, 5)
        }
        .navigationTitle("Capsules")
        .onAppear {
            viewModel.fetchTimeCapsules()
        }
        .sheet(isPresented: $showingAddSheet) {
            AddWatchTimeCapsuleView(viewModel: viewModel)
        }
    }
}

struct AddWatchTimeCapsuleView: View {
    @ObservedObject var viewModel: WatchTimeCapsuleViewModel
    @Environment(\.dismiss) var dismiss

    // Simplified date options for watch
    enum QuickDateOption: String, CaseIterable, Identifiable {
        case oneDay = "In 1 Day"
        case oneWeek = "In 1 Week"
        case oneMonth = "In 1 Month"
        case oneYear = "In 1 Year"
        case custom = "Custom"
        var id: String { self.rawValue }

        func date(from currentDate: Date) -> Date {
            let calendar = Calendar.current
            switch self {
            case .oneDay: return calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            case .oneWeek: return calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
            case .oneMonth: return calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            case .oneYear: return calendar.date(byAdding: .year, value: 1, to: currentDate) ?? currentDate
            case .custom: return currentDate // For custom DatePicker
            }
        }
    }
    @State private var selectedQuickDate = QuickDateOption.oneYear
    @State private var showingCustomDatePicker = false

    var body: some View {
        ScrollView { // Make content scrollable if it overflows
            VStack(spacing: 12) {
                Text("New Time Capsule")
                    .font(.headline)

                TextField("Capsule Note", text: $viewModel.newCapsuleNote)

                Text("Open Date:")
                    .font(.caption)

                if showingCustomDatePicker {
                    DatePicker(
                        "", // No label needed here
                        selection: $viewModel.newCapsuleOpenDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical) // Or .wheel
                    .labelsHidden()
                    Button("Done Custom Date") { showingCustomDatePicker = false }
                } else {
                    Picker("Select Open Date", selection: $selectedQuickDate) {
                        ForEach(QuickDateOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedQuickDate) { newOption in
                        if newOption == .custom {
                            showingCustomDatePicker = true
                            // Keep current newCapsuleOpenDate or set to a default for custom picker
                        } else {
                            showingCustomDatePicker = false
                            viewModel.newCapsuleOpenDate = newOption.date(from: Date())
                        }
                    }
                    .onAppear { // Initialize date based on picker default
                        if selectedQuickDate != .custom {
                           viewModel.newCapsuleOpenDate = selectedQuickDate.date(from: Date())
                        }
                    }
                }

                Button("Save Capsule") {
                    viewModel.addTimeCapsule()
                }
                .disabled(viewModel.newCapsuleNote.isEmpty || viewModel.isLoading)
                .buttonStyle(.borderedProminent) // Make it stand out

                if viewModel.isLoading {
                    ProgressView()
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }

                Button("Cancel") { dismiss() }
                    .foregroundColor(.red)
            }
            .padding()
        }
        .navigationTitle("Add Capsule") // Will be shown if view is in NavigationView from sheet
        .onAppear {
            viewModel.errorMessage = nil
            viewModel.addCapsuleSuccess = false
        }
        .onChange(of: viewModel.addCapsuleSuccess) { success in
            if success {
                dismiss()
                WKInterfaceDevice.current().play(.success)
            }
        }
    }
}

struct WatchRemindersView: View {
    @StateObject private var viewModel = WatchRemindersViewModel()
    @State private var showingAddReminderSheet = false
    @State private var newReminderText = "" // For TextField in the sheet

    var body: some View {
        VStack {
            if viewModel.isLoading && viewModel.reminders.isEmpty && viewModel.triggeredReminders.isEmpty {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            } else if viewModel.reminders.isEmpty && viewModel.triggeredReminders.isEmpty {
                Text("No reminders.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                List {
                    if !viewModel.triggeredReminders.isEmpty {
                        Section(header: Text("Triggered").foregroundColor(.orange)) {
                            ForEach(viewModel.triggeredReminders) { reminder in
                                reminderRow(reminder: reminder, isTriggered: true)
                            }
                            // No onDelete for triggered reminders as they are notifications
                        }
                    }

                    Section(header: Text("Active Reminders")) {
                        ForEach(viewModel.reminders) { reminder in
                            reminderRow(reminder: reminder)
                        }
                        .onDelete(perform: viewModel.deleteReminder)
                    }
                }
            }

            Spacer()

            Button {
                newReminderText = "" // Reset text field
                showingAddReminderSheet = true
            } label: {
                Label("Add Here", systemImage: "plus.circle.fill")
            }
            .padding(.top, 5)
        }
        .navigationTitle("Reminders")
        .onAppear {
            viewModel.requestLocationAccessIfNeeded() // Request location for "Add Here" and triggers
            viewModel.fetchReminders()
        }
        .sheet(isPresented: $showingAddReminderSheet) {
            WatchAddReminderView(viewModel: viewModel, reminderText: $newReminderText)
        }
    }

    @ViewBuilder
    private func reminderRow(reminder: LocationReminder, isTriggered: Bool = false) -> some View {
        VStack(alignment: .leading) {
            Text(reminder.reminder) // 'reminder' field holds the note
                .font(.headline)
                .foregroundColor(isTriggered ? .orange : .primary)
            Text("At: \(reminder.place_name)")
                .font(.caption2)
            Text("Set: \(Date(timeIntervalSince1970: reminder.created_at), style: .relative) ago")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

struct WatchAddReminderView: View {
    @ObservedObject var viewModel: WatchRemindersViewModel
    @Binding var reminderText: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 15) {
            Text("Remind me here...")
                .font(.headline)

            TextField("Note for reminder", text: $reminderText)

            Button("Save Reminder") {
                viewModel.addReminderHere(note: reminderText)
                // The success/failure will be handled by observing viewModel.addReminderSuccess if needed,
                // or just dismiss optimistically. For now, dismiss.
                dismiss()
            }
            .disabled(reminderText.isEmpty || viewModel.isLoading)

            if viewModel.isLoading {
                ProgressView()
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }

            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.red)
            .padding(.top, 5)
        }
        .padding()
        .onAppear {
            viewModel.errorMessage = nil // Clear error when sheet appears
            viewModel.addReminderSuccess = false // Reset flag
        }
        .onChange(of: viewModel.addReminderSuccess) { success in
            if success {
                dismiss()
                // Optionally provide haptic feedback
                WKInterfaceDevice.current().play(.success)
            }
        }
    }
}

struct WatchPlacesView: View {
    @StateObject private var viewModel = WatchPlacesViewModel()
    @State private var showingSearchInput = false
    @State private var searchText = "" // For TextField

    // Define some quick search categories for watchOS
    let searchCategories = ["food", "cafe", "shop", "park"]

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if viewModel.searchResults.isEmpty {
                Text("No places found. Try a search.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                List(viewModel.searchResults) { place in
                    NavigationLink(destination: WatchPlaceDetailView(place: place)) {
                        VStack(alignment: .leading) {
                            Text(place.name)
                                .font(.headline)
                            if let vicinity = place.vicinity, !vicinity.isEmpty {
                                Text(vicinity)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }

            Spacer() // Pushes buttons to the bottom if list is short or empty

            // Search Activation / Category Buttons
            HStack {
                Button { // Text search
                    showingSearchInput = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .sheet(isPresented: $showingSearchInput) {
                    WatchPlacesSearchInputView(viewModel: viewModel)
                }

                // Example of a category button
                if !searchCategories.isEmpty {
                    Button(searchCategories[0].capitalized) {
                        viewModel.searchQuery = "" // Clear text field query
                        viewModel.searchPlaces(type: searchCategories[0])
                    }
                }
            }
            .padding(.top, 5)
        }
        .navigationTitle("Places")
        .onAppear {
            // Request location when view appears, if needed for initial search or context
            viewModel.requestLocationAccessIfNeeded()
            // Perform an initial search if desired, e.g., for a default category
            // if viewModel.searchResults.isEmpty {
            //     viewModel.searchPlaces(type: "food") // Example initial search
            // }
        }
    }
}

// Simple text input view for place search
struct WatchPlacesSearchInputView: View {
    @ObservedObject var viewModel: WatchPlacesViewModel // Use ObservedObject for passed VMs
    @Environment(\.dismiss) var dismiss
    @State private var localSearchText: String = ""

    var body: some View {
        VStack {
            Text("Search Places")
                .font(.headline)
                .padding(.bottom)

            TextField("e.g., park, cafe", text: $localSearchText)

            Button("Search") {
                viewModel.searchQuery = localSearchText // Set it on the ViewModel
                viewModel.searchPlaces() // ViewModel uses its own searchQuery
                dismiss()
            }
            .disabled(localSearchText.isEmpty)
            .padding(.top)

            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.red)
        }
        .padding()
    }
}

// Detail view for a selected place
struct WatchPlaceDetailView: View {
    let place: Place // Using the simplified Place model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(place.name)
                    .font(.title3)
                    .padding(.bottom, 4)

                if let vicinity = place.vicinity, !vicinity.isEmpty {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                        Text(vicinity)
                    }
                    .font(.caption)
                }

                if let rating = place.rating {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                        if let types = place.types, let firstType = types.first {
                             Text("(\(firstType.replacingOccurrences(of: "_", with: " ").capitalized))")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .font(.caption)
                }

                // Add more details if available and relevant for watch
                // e.g., Text("Types: \(place.types?.joined(separator: ", ") ?? "N/A")").font(.caption2)

                // "Open in Maps" on iPhone is complex. For now, just display info.
                // A button could be added to trigger a specific action if defined.
                // For instance, sending a notification to the phone to open this place.
                // Button("Show on Phone") { /* Logic to notify iPhone */ }
            }
            .padding()
        }
        .navigationTitle(place.name)
    }
}


#Preview {
    WatchContentView()
}

