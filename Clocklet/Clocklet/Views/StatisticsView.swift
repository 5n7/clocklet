//
//  StatisticsView.swift
//  Clocklet
//

import Charts
import SwiftUI

enum StatisticsPeriod: String, CaseIterable {
    case threeMonths = "3M"
    case sixMonths = "6M"
    case twelveMonths = "12M"
    case all = "All"

    var monthCount: Int? {
        switch self {
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .twelveMonths: return 12
        case .all: return nil
        }
    }
}

@MainActor
struct StatisticsView: View {
    @Bindable var viewModel: ClockViewModel
    @State private var selectedPeriod: StatisticsPeriod = .sixMonths
    @State private var hoveredStat: MonthlyStatistics?

    private var statistics: [MonthlyStatistics] {
        let allStats = viewModel.monthlyStatistics(months: 120)
        guard let monthCount = selectedPeriod.monthCount else {
            return allStats.filter { $0.totalSeconds > 0 || isRecentMonth($0) }
        }
        return Array(allStats.suffix(monthCount))
    }

    private func isRecentMonth(_ stat: MonthlyStatistics) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let currentYear = components.year, let currentMonth = components.month else {
            return false
        }
        let monthsDiff = (currentYear - stat.year) * 12 + (currentMonth - stat.month)
        return monthsDiff <= 2
    }

    private var totalHours: Double {
        statistics.reduce(0) { $0 + $1.totalHours }
    }

    private var averageHoursPerMonth: Double {
        let nonZeroMonths = statistics.filter { $0.totalSeconds > 0 }
        guard !nonZeroMonths.isEmpty else { return 0 }
        return nonZeroMonths.reduce(0) { $0 + $1.totalHours } / Double(nonZeroMonths.count)
    }

    private var peakMonth: MonthlyStatistics? {
        statistics.max { $0.totalSeconds < $1.totalSeconds }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Period Selector
            periodSelector
                .padding()

            Divider()

            if statistics.isEmpty || statistics.allSatisfy({ $0.totalSeconds == 0 }) {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Chart
                        chartView
                            .padding(.horizontal)
                            .padding(.top)

                        Divider()
                            .padding(.horizontal)

                        // Summary
                        summaryView
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var periodSelector: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 300)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Data")
                .font(.headline)
            Text("Start tracking time to see your statistics.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chartView: some View {
        VStack(spacing: 8) {
            // Tooltip area (fixed height to prevent layout shift)
            Group {
                if let stat = hoveredStat {
                    HStack(spacing: 8) {
                        Text(stat.displayLabel)
                            .fontWeight(.medium)
                        Text(DurationFormatter.format(stat.totalDuration))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    .font(.callout)
                } else {
                    Text(" ")
                        .font(.callout)
                }
            }
            .frame(height: 20)

            Chart(statistics) { stat in
                BarMark(
                    x: .value("Month", stat.shortLabel),
                    y: .value("Hours", stat.totalHours)
                )
                .foregroundStyle(
                    hoveredStat?.id == stat.id
                        ? Color.accentColor
                        : Color.accentColor.opacity(0.7)
                )
                .cornerRadius(4)
            }
            .chartYAxisLabel("Hours")
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                guard let plotFrame = proxy.plotFrame,
                                      !statistics.isEmpty else {
                                    hoveredStat = nil
                                    return
                                }
                                let plotArea = geometry[plotFrame]
                                let relativeX = location.x - plotArea.origin.x
                                let barWidth = plotArea.width / CGFloat(statistics.count)
                                let index = Int(relativeX / barWidth)
                                if index >= 0, index < statistics.count {
                                    hoveredStat = statistics[index]
                                } else {
                                    hoveredStat = nil
                                }
                            case .ended:
                                hoveredStat = nil
                            }
                        }
                }
            }
            .frame(height: 200)
        }
    }

    private var summaryView: some View {
        HStack(spacing: 32) {
            summaryItem(
                title: "Total",
                value: String(format: "%.1f h", totalHours),
                icon: "clock.fill"
            )

            summaryItem(
                title: "Average",
                value: String(format: "%.1f h/mo", averageHoursPerMonth),
                icon: "chart.line.uptrend.xyaxis"
            )

            if let peak = peakMonth, peak.totalSeconds > 0 {
                summaryItem(
                    title: "Peak",
                    value: String(format: "%.1f h", peak.totalHours),
                    subtitle: peak.displayLabel,
                    icon: "star.fill"
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func summaryItem(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String
    ) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 100)
    }
}
