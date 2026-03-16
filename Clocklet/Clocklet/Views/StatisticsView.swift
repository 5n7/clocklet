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

enum StatisticsMetric: String, CaseIterable {
  case hours = "Hours"
  case earnings = "Earnings"
}

@MainActor
struct StatisticsView: View {
  @Bindable var viewModel: ClockViewModel
  @State private var selectedPeriod: StatisticsPeriod = .sixMonths
  @State private var selectedMetric: StatisticsMetric = .hours
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

  // MARK: - Hours metrics

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

  // MARK: - Earnings metrics

  private var hourlyRate: Int { SettingsManager.shared.hourlyRate }

  private func earnings(for stat: MonthlyStatistics) -> Int {
    EarningsCalculator.calculate(hourlyRate: hourlyRate, durationSeconds: stat.totalDuration)
  }

  private var totalEarnings: Int {
    statistics.reduce(0) { $0 + earnings(for: $1) }
  }

  private var averageEarningsPerMonth: Int {
    let nonZeroMonths = statistics.filter { $0.totalSeconds > 0 }
    guard !nonZeroMonths.isEmpty else { return 0 }
    return nonZeroMonths.reduce(0) { $0 + earnings(for: $1) } / nonZeroMonths.count
  }

  private var showEarnings: Bool { SettingsManager.shared.isEarningsEnabled }

  // MARK: - Body

  var body: some View {
    VStack(spacing: 0) {
      // Selectors
      HStack(spacing: 16) {
        periodSelector

        if showEarnings {
          metricSelector
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)

      Divider()

      if statistics.isEmpty || statistics.allSatisfy({ $0.totalSeconds == 0 }) {
        emptyState
      } else {
        ScrollView {
          VStack(spacing: 24) {
            chartView
              .padding(.horizontal, 20)
              .padding(.top, 16)

            Divider()
              .padding(.horizontal, 20)

            summaryView
              .padding(.horizontal, 20)
              .padding(.bottom, 20)
          }
        }
      }
    }
    .frame(minWidth: 560, idealWidth: 600, minHeight: 460, idealHeight: 500)
  }

  // MARK: - Selectors

  private var periodSelector: some View {
    Picker("Period", selection: $selectedPeriod) {
      ForEach(StatisticsPeriod.allCases, id: \.self) { period in
        Text(period.rawValue).tag(period)
      }
    }
    .pickerStyle(.segmented)
    .frame(maxWidth: 260)
  }

  private var metricSelector: some View {
    Picker("Metric", selection: $selectedMetric) {
      ForEach(StatisticsMetric.allCases, id: \.self) { metric in
        Text(metric.rawValue).tag(metric)
      }
    }
    .pickerStyle(.segmented)
    .frame(maxWidth: 180)
  }

  // MARK: - Empty state

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

  // MARK: - Chart

  private var chartView: some View {
    VStack(spacing: 8) {
      // Tooltip
      Group {
        if let stat = hoveredStat {
          tooltipContent(for: stat)
        } else {
          Text(" ")
            .font(.callout)
        }
      }
      .frame(height: 22)
      .animation(.none, value: hoveredStat?.id)

      if selectedMetric == .earnings && showEarnings {
        earningsChart
      } else {
        hoursChart
      }
    }
  }

  private func tooltipContent(for stat: MonthlyStatistics) -> some View {
    HStack(spacing: 8) {
      Text(stat.displayLabel)
        .fontWeight(.medium)
      if selectedMetric == .hours || !showEarnings {
        Text(DurationFormatter.format(stat.totalDuration))
          .monospacedDigit()
          .foregroundColor(.secondary)
      }
      if selectedMetric == .earnings && showEarnings {
        Text(EarningsCalculator.format(earnings(for: stat)))
          .monospacedDigit()
          .foregroundColor(.orange)
      }
    }
    .font(.callout)
  }

  private var hoursChart: some View {
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
      hoverOverlay(proxy: proxy)
    }
    .frame(height: 220)
  }

  private var earningsChart: some View {
    Chart(statistics) { stat in
      BarMark(
        x: .value("Month", stat.shortLabel),
        y: .value("Earnings", earnings(for: stat))
      )
      .foregroundStyle(
        hoveredStat?.id == stat.id
          ? Color.orange
          : Color.orange.opacity(0.7)
      )
      .cornerRadius(4)
    }
    .chartYAxisLabel("Earnings")
    .chartXAxis {
      AxisMarks(values: .automatic) { _ in
        AxisValueLabel()
      }
    }
    .chartOverlay { proxy in
      hoverOverlay(proxy: proxy)
    }
    .frame(height: 220)
  }

  private func hoverOverlay(proxy: ChartProxy) -> some View {
    GeometryReader { geometry in
      Rectangle()
        .fill(.clear)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
          switch phase {
          case .active(let location):
            guard let plotFrame = proxy.plotFrame,
              !statistics.isEmpty
            else {
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

  // MARK: - Summary

  private var summaryView: some View {
    HStack(spacing: 0) {
      if selectedMetric == .earnings && showEarnings {
        earningsSummary
      } else {
        hoursSummary
      }
    }
    .frame(maxWidth: .infinity)
  }

  private var hoursSummary: some View {
    HStack(spacing: 0) {
      summaryItem(
        title: "Total",
        value: String(format: "%.1f h", totalHours),
        icon: "clock.fill"
      )
      .frame(maxWidth: .infinity)

      summaryItem(
        title: "Average",
        value: String(format: "%.1f h/mo", averageHoursPerMonth),
        icon: "chart.line.uptrend.xyaxis"
      )
      .frame(maxWidth: .infinity)

      if let peak = peakMonth, peak.totalSeconds > 0 {
        summaryItem(
          title: "Peak",
          value: String(format: "%.1f h", peak.totalHours),
          subtitle: peak.displayLabel,
          icon: "star.fill"
        )
        .frame(maxWidth: .infinity)
      }
    }
  }

  private var earningsSummary: some View {
    HStack(spacing: 0) {
      summaryItem(
        title: "Total",
        value: EarningsCalculator.format(totalEarnings),
        icon: "banknote.fill",
        tint: .orange
      )
      .frame(maxWidth: .infinity)

      summaryItem(
        title: "Average",
        value: "\(EarningsCalculator.format(averageEarningsPerMonth))/mo",
        icon: "chart.line.uptrend.xyaxis",
        tint: .orange
      )
      .frame(maxWidth: .infinity)

      if let peak = peakMonth, peak.totalSeconds > 0 {
        summaryItem(
          title: "Peak",
          value: EarningsCalculator.format(earnings(for: peak)),
          subtitle: peak.displayLabel,
          icon: "star.fill",
          tint: .orange
        )
        .frame(maxWidth: .infinity)
      }
    }
  }

  private func summaryItem(
    title: String,
    value: String,
    subtitle: String? = nil,
    icon: String,
    tint: Color = .accentColor
  ) -> some View {
    VStack(spacing: 4) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundColor(tint)

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
  }
}
