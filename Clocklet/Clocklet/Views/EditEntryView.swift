//
//  EditEntryView.swift
//  Clocklet
//

import SwiftUI

struct EditEntryView: View {
    enum Mode {
        case add
        case edit(TimeEntry)

        var title: String {
            switch self {
            case .add: return "Add Entry"
            case .edit: return "Edit Entry"
            }
        }
    }

    let mode: Mode
    let onSave: (Date, Date) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var clockIn: Date
    @State private var clockOut: Date
    @State private var showError = false
    @State private var errorMessage = ""

    init(mode: Mode, onSave: @escaping (Date, Date) -> Void) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .add:
            let now = Date()
            _clockIn = State(initialValue: now.addingTimeInterval(-3600)) // 1 hour ago
            _clockOut = State(initialValue: now)
        case .edit(let entry):
            _clockIn = State(initialValue: entry.clockIn)
            _clockOut = State(initialValue: entry.clockOut)
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(mode.title)
                .font(.headline)

            Form {
                DatePicker("Clock In", selection: $clockIn)
                DatePicker("Clock Out", selection: $clockOut)

                if clockOut > clockIn {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(DurationFormatter.format(Int(clockOut.timeIntervalSince(clockIn))))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Save") {
                    if clockOut <= clockIn {
                        errorMessage = "Clock Out must be after Clock In"
                        showError = true
                    } else {
                        onSave(clockIn, clockOut)
                        dismiss()
                    }
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 350, height: 280)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
}
