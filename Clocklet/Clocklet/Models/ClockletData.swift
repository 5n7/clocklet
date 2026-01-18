//
//  ClockletData.swift
//  Clocklet
//

import Foundation

struct ClockletData: Codable, Equatable {
    var version: Int = 1
    var currentSession: CurrentSession?
    var entries: [TimeEntry] = []
}
