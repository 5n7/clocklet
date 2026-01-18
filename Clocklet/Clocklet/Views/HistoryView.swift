//
//  HistoryView.swift
//  Clocklet
//

import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: ClockViewModel
    @State private var selectedEntry: TimeEntry?
    @State private var isAddingEntry = false
    @State private var selectedEntries: Set<TimeEntry.ID> = []
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.entriesByDate.isEmpty {
                    ContentUnavailableView(
                        "No Entries",
                        systemImage: "clock",
                        description: Text("Clock in to start tracking your time.")
                    )
                } else {
                    List {
                        ForEach(viewModel.entriesByDate, id: \.date) { group in
                            Section(header: sectionHeader(for: group.date, entries: group.entries)) {
                                ForEach(group.entries) { entry in
                                    HStack(spacing: 12) {
                                        // Checkbox
                                        Image(systemName: selectedEntries.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedEntries.contains(entry.id) ? .accentColor : .secondary)
                                            .font(.title3)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                toggleSelection(entry.id)
                                            }

                                        // Entry content
                                        HistoryRowView(entry: entry)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedEntry = entry
                                            }
                                    }
                                    .contextMenu {
                                        Button("Edit") {
                                            selectedEntry = entry
                                        }
                                        Button("Delete", role: .destructive) {
                                            viewModel.deleteEntry(entry)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if !selectedEntries.isEmpty {
                        Button("Deselect All") {
                            selectedEntries.removeAll()
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Delete (\(selectedEntries.count))")
                        }
                    } else if !viewModel.data.entries.isEmpty {
                        Button("Select All") {
                            selectAll()
                        }
                        .keyboardShortcut("a", modifiers: .command)
                    }

                    Button(action: { isAddingEntry = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $selectedEntry) { entry in
                EditEntryView(
                    mode: .edit(entry),
                    onSave: { clockIn, clockOut in
                        viewModel.updateEntry(entry, clockIn: clockIn, clockOut: clockOut)
                    }
                )
            }
            .sheet(isPresented: $isAddingEntry) {
                EditEntryView(
                    mode: .add,
                    onSave: { clockIn, clockOut in
                        viewModel.addEntry(clockIn: clockIn, clockOut: clockOut)
                    }
                )
            }
            .confirmationDialog(
                "Delete \(selectedEntries.count) entries?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    viewModel.deleteEntries(selectedEntries)
                    selectedEntries.removeAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .onKeyPress(.escape) {
                if !selectedEntries.isEmpty {
                    selectedEntries.removeAll()
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.delete) {
                if !selectedEntries.isEmpty {
                    showDeleteConfirmation = true
                    return .handled
                }
                return .ignored
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func toggleSelection(_ id: TimeEntry.ID) {
        if selectedEntries.contains(id) {
            selectedEntries.remove(id)
        } else {
            selectedEntries.insert(id)
        }
    }

    private func selectAll() {
        selectedEntries = Set(viewModel.data.entries.map(\.id))
    }

    private func sectionHeader(for date: String, entries: [TimeEntry]) -> some View {
        HStack {
            Text(formatDateHeader(date))
            Spacer()
            Text(DurationFormatter.format(entries.reduce(0) { $0 + $1.durationSeconds }))
                .foregroundColor(.secondary)
        }
    }

    private func formatDateHeader(_ dateString: String) -> String {
        guard let date = DateFormatters.dateOnly.date(from: dateString) else {
            return dateString
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd (E)"
            return formatter.string(from: date)
        }
    }
}

struct HistoryRowView: View {
    let entry: TimeEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(DateFormatters.timeOnly.string(from: entry.clockIn)) - \(DateFormatters.timeOnly.string(from: entry.clockOut))")
                    .font(.body)
                    .monospacedDigit()

                if entry.modifiedAt != nil {
                    Text("Edited")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(DurationFormatter.format(entry.durationSeconds))
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}
