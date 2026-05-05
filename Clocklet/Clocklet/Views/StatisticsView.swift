//
//  StatisticsView.swift
//  Clocklet
//

import Charts
import SwiftUI

enum StatisticsPeriod: String, CaseIterable {
  case oneMonth = "1M"
  case threeMonths = "3M"
  case sixMonths = "6M"
  case twelveMonths = "12M"
  case all = "All"

  var monthCount: Int? {
    switch self {
    case .oneMonth: return 1
    case .threeMonths: return 3
    case .sixMonths: return 6
    case .twelveMonths: return 12
    case .all: return nil
    }
  }

  var isDaily: Bool {
    self == .oneMonth
  }
}

enum StatisticsMetric: String, CaseIterable {
  case hours = "Hours"
  case earnings = "Earnings"
}

/// Lightweight wrapper so daily and monthly stats can share chart/summary code.
private struct ChartDataPoint: Identifiable {
  let id: String
  let label: String
  let shortLabel: String
  let totalSeconds: Int
  let totalEarnings: Int

  var totalHours: Double { Double(totalSeconds) / 3600.0 }
  var totalDuration: TimeInterval { TimeInterval(totalSeconds) }
}

private struct JobBreakdownPoint: Identifiable {
  let id: String
  let jobName: String
  let totalSeconds: Int
  let totalEarnings: Int

  var totalDuration: TimeInterval { TimeInterval(totalSeconds) }
}

@MainActor
struct StatisticsView: View {
  @Bindable var viewModel: ClockViewModel
  @State private var selectedPeriod: StatisticsPeriod = .sixMonths
  @State private var selectedMetric: StatisticsMetric = .hours
  @State private var hoveredPoint: ChartDataPoint?
  @State private var timelineMonthOffset = 0

  private var calendar: Calendar { Calendar.current }
  private var currentMonth: Date {
    calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
  }
  private var maxTimelineOffset: Int {
    guard let oldestMonth = viewModel.oldestStatisticsMonth else { return 0 }
    return max(calendar.dateComponents([.month], from: oldestMonth, to: currentMonth).month ?? 0, 0)
  }
  private var effectiveTimelineMonthOffset: Int {
    min(timelineMonthOffset, maxTimelineOffset)
  }
  private var timelineAnchorMonth: Date {
    calendar.date(byAdding: .month, value: -effectiveTimelineMonthOffset, to: currentMonth)
      ?? currentMonth
  }
  private var canNavigateBackward: Bool {
    selectedPeriod != .all && effectiveTimelineMonthOffset < maxTimelineOffset
  }
  private var canNavigateForward: Bool {
    selectedPeriod != .all && effectiveTimelineMonthOffset > 0
  }
  private var timelineTitle: String {
    if selectedPeriod.isDaily {
      return DateFormatters.monthYear.string(from: timelineAnchorMonth)
    }
    guard let monthCount = selectedPeriod.monthCount else {
      return "All Time"
    }
    guard
      let startMonth = calendar.date(
        byAdding: .month, value: -(monthCount - 1), to: timelineAnchorMonth)
    else {
      return DateFormatters.monthYear.string(from: timelineAnchorMonth)
    }
    return
      "\(DateFormatters.monthYear.string(from: startMonth)) - \(DateFormatters.monthYear.string(from: timelineAnchorMonth))"
  }

  private var chartData: [ChartDataPoint] {
    if selectedPeriod.isDaily {
      return viewModel.dailyStatistics(forMonthContaining: timelineAnchorMonth).map {
        ChartDataPoint(
          id: $0.id, label: $0.displayLabel, shortLabel: $0.shortLabel,
          totalSeconds: $0.totalSeconds,
          totalEarnings: $0.totalEarnings
        )
      }
    }
    let filtered: [MonthlyStatistics]
    if let monthCount = selectedPeriod.monthCount {
      filtered = viewModel.monthlyStatistics(months: monthCount, endingAt: timelineAnchorMonth)
    } else {
      let monthSpan = max(maxTimelineOffset + 1, 3)
      let allStats = viewModel.monthlyStatistics(months: monthSpan, endingAt: currentMonth)
      filtered = allStats.filter { $0.totalSeconds > 0 || isRecentMonth($0) }
    }
    return filtered.map {
      ChartDataPoint(
        id: $0.id,
        label: $0.displayLabel,
        shortLabel: $0.shortLabel,
        totalSeconds: $0.totalSeconds,
        totalEarnings: $0.totalEarnings
      )
    }
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

  private var showEarnings: Bool { SettingsManager.shared.isEarningsEnabled }

  private func totalHours(_ data: [ChartDataPoint]) -> Double {
    data.reduce(0) { $0 + $1.totalHours }
  }

  private func averageHours(_ data: [ChartDataPoint]) -> Double {
    let nonZero = data.filter { $0.totalSeconds > 0 }
    guard !nonZero.isEmpty else { return 0 }
    return nonZero.reduce(0) { $0 + $1.totalHours } / Double(nonZero.count)
  }

  private func peak(_ data: [ChartDataPoint]) -> ChartDataPoint? {
    data.max { $0.totalSeconds < $1.totalSeconds }
  }

  private func totalEarnings(_ data: [ChartDataPoint]) -> Int {
    data.reduce(0) { $0 + $1.totalEarnings }
  }

  private func averageEarnings(_ data: [ChartDataPoint]) -> Int {
    let nonZero = data.filter { $0.totalEarnings > 0 }
    guard !nonZero.isEmpty else { return 0 }
    return nonZero.reduce(0) { $0 + $1.totalEarnings } / nonZero.count
  }

  private func peakEarnings(_ data: [ChartDataPoint]) -> ChartDataPoint? {
    data.max { $0.totalEarnings < $1.totalEarnings }
  }

  private var jobBreakdown: [JobBreakdownPoint] {
    let interval = selectedPeriodInterval
    var totals: [String: (seconds: Int, earnings: Int)] = [:]

    for entry in viewModel.data.entries {
      let duration = durationWithinSelectedPeriod(from: entry.clockIn, to: entry.clockOut, interval: interval)
      guard duration > 0 else { continue }
      totals[entry.jobName, default: (seconds: 0, earnings: 0)].seconds += duration
      totals[entry.jobName, default: (seconds: 0, earnings: 0)].earnings +=
        EarningsCalculator.calculate(
          hourlyRate: entry.hourlyRate,
          durationSeconds: TimeInterval(duration)
        )
    }

    if let session = viewModel.data.currentSession {
      let duration = durationWithinSelectedPeriod(from: session.clockIn, to: Date(), interval: interval)
      totals[session.jobName, default: (seconds: 0, earnings: 0)].seconds += duration
      totals[session.jobName, default: (seconds: 0, earnings: 0)].earnings +=
        EarningsCalculator.calculate(
          hourlyRate: session.hourlyRate,
          durationSeconds: TimeInterval(duration)
        )
    }

    return totals
      .map {
        JobBreakdownPoint(
          id: $0.key,
          jobName: $0.key,
          totalSeconds: $0.value.seconds,
          totalEarnings: $0.value.earnings
        )
      }
      .sorted {
        if $0.totalEarnings == $1.totalEarnings {
          return $0.totalSeconds > $1.totalSeconds
        }
        return $0.totalEarnings > $1.totalEarnings
      }
  }

  private func durationWithinSelectedPeriod(from start: Date, to end: Date, interval: DateInterval?) -> Int {
    guard let interval else {
      return max(Int(end.timeIntervalSince(start)), 0)
    }

    let effectiveStart = max(start, interval.start)
    let effectiveEnd = min(end, interval.end)
    return max(Int(effectiveEnd.timeIntervalSince(effectiveStart)), 0)
  }

  private var selectedPeriodInterval: DateInterval? {
    guard selectedPeriod != .all else { return nil }

    let startMonth: Date
    if selectedPeriod.isDaily {
      startMonth = timelineAnchorMonth
    } else {
      guard let monthCount = selectedPeriod.monthCount,
        let date = calendar.date(
          byAdding: .month,
          value: -(monthCount - 1),
          to: timelineAnchorMonth
        )
      else {
        return nil
      }
      startMonth = date
    }

    guard let endMonth = calendar.date(byAdding: .month, value: 1, to: timelineAnchorMonth) else {
      return nil
    }

    return DateInterval(start: startMonth, end: endMonth)
  }

  var body: some View {
    let data = chartData
    let hasData = !data.isEmpty && !data.allSatisfy({ $0.totalSeconds == 0 })

    VStack(spacing: 0) {
      HStack(spacing: 16) {
        periodSelector
        if showEarnings { metricSelector }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)

      Divider()

      if selectedPeriod != .all {
        timelineNavigator
          .padding(.horizontal, 20)
          .padding(.vertical, 12)

        Divider()
      }

      if !hasData {
        emptyState
      } else {
        ScrollView {
          VStack(spacing: 24) {
            chartSection(data: data)
              .padding(.horizontal, 20)
              .padding(.top, 16)

            Divider()
              .padding(.horizontal, 20)

            summarySection(data: data)
              .padding(.horizontal, 20)

            if showEarnings {
              Divider()
                .padding(.horizontal, 20)

              jobBreakdownSection(data: jobBreakdown)
                .padding(.horizontal, 20)
            }

            Spacer(minLength: 0)
              .padding(.bottom, 20)
          }
        }
      }
    }
    .frame(minWidth: 560, idealWidth: 600, minHeight: 460, idealHeight: 500)
    .onChange(of: selectedPeriod) { _, _ in
      timelineMonthOffset = 0
      hoveredPoint = nil
    }
  }

  private var periodSelector: some View {
    Picker("Period", selection: $selectedPeriod) {
      ForEach(StatisticsPeriod.allCases, id: \.self) { period in
        Text(period.rawValue).tag(period)
      }
    }
    .pickerStyle(.segmented)
    .frame(maxWidth: 320)
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

  private var timelineNavigator: some View {
    HStack(spacing: 12) {
      Button(action: navigateBackward) {
        Image(systemName: "chevron.left")
      }
      .disabled(!canNavigateBackward)

      Spacer()

      Text(timelineTitle)
        .font(.headline)
        .monospacedDigit()

      Spacer()

      Button(action: navigateForward) {
        Image(systemName: "chevron.right")
      }
      .disabled(!canNavigateForward)
    }
    .buttonStyle(.borderless)
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

  private func chartSection(data: [ChartDataPoint]) -> some View {
    let isEarnings = selectedMetric == .earnings && showEarnings
    let tint: Color = isEarnings ? .orange : .accentColor
    let axisLabel = selectedPeriod.isDaily ? "Day" : "Month"

    return VStack(spacing: 8) {
      // Tooltip
      Group {
        if let point = hoveredPoint {
          tooltipContent(label: point.label, duration: point.totalDuration)
        } else {
          Text(" ").font(.callout)
        }
      }
      .frame(height: 22)
      .animation(.none, value: hoveredPoint?.id)

      Chart(data) { point in
        let yValue = isEarnings ? Double(point.totalEarnings) : point.totalHours
        BarMark(
          x: .value(axisLabel, point.shortLabel),
          y: .value(isEarnings ? "Earnings" : "Hours", yValue)
        )
        .foregroundStyle(
          hoveredPoint?.id == point.id ? tint : tint.opacity(0.7)
        )
        .cornerRadius(4)
      }
      .chartYAxisLabel(isEarnings ? "Earnings" : "Hours")
      .chartXAxis {
        AxisMarks(values: .automatic) { _ in
          AxisValueLabel()
        }
      }
      .chartOverlay { proxy in
        hoverOverlay(proxy: proxy, data: data)
      }
      .frame(height: 220)
    }
  }

  private func tooltipContent(label: String, duration: TimeInterval) -> some View {
    HStack(spacing: 8) {
      Text(label)
        .fontWeight(.medium)
      if selectedMetric == .hours || !showEarnings {
        Text(DurationFormatter.format(duration))
          .monospacedDigit()
          .foregroundColor(.secondary)
      }
      if selectedMetric == .earnings && showEarnings {
        if let point = hoveredPoint {
          Text(EarningsCalculator.format(point.totalEarnings))
            .monospacedDigit()
            .foregroundColor(.orange)
        }
      }
    }
    .font(.callout)
  }

  private func hoverOverlay(proxy: ChartProxy, data: [ChartDataPoint]) -> some View {
    GeometryReader { geometry in
      Rectangle()
        .fill(.clear)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
          switch phase {
          case .active(let location):
            guard let plotFrame = proxy.plotFrame, !data.isEmpty else {
              hoveredPoint = nil
              return
            }
            let plotArea = geometry[plotFrame]
            let relativeX = location.x - plotArea.origin.x
            let barWidth = plotArea.width / CGFloat(data.count)
            let index = Int(relativeX / barWidth)
            if index >= 0, index < data.count {
              hoveredPoint = data[index]
            } else {
              hoveredPoint = nil
            }
          case .ended:
            hoveredPoint = nil
          }
        }
    }
  }

  private func navigateBackward() {
    guard canNavigateBackward else { return }
    hoveredPoint = nil
    timelineMonthOffset = effectiveTimelineMonthOffset + 1
  }

  private func navigateForward() {
    guard canNavigateForward else { return }
    hoveredPoint = nil
    timelineMonthOffset = max(effectiveTimelineMonthOffset - 1, 0)
  }

  private func summarySection(data: [ChartDataPoint]) -> some View {
    HStack(spacing: 0) {
      if selectedMetric == .earnings && showEarnings {
        earningsSummary(data: data)
      } else {
        hoursSummary(data: data)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func hoursSummary(data: [ChartDataPoint]) -> some View {
    let periodSuffix = selectedPeriod.isDaily ? "day" : "mo"
    return HStack(spacing: 0) {
      summaryItem(
        title: "Total",
        value: String(format: "%.1f h", totalHours(data)),
        icon: "clock.fill"
      )
      .frame(maxWidth: .infinity)

      summaryItem(
        title: "Average",
        value: String(format: "%.1f h/\(periodSuffix)", averageHours(data)),
        icon: "chart.line.uptrend.xyaxis"
      )
      .frame(maxWidth: .infinity)

      if let p = peak(data), p.totalSeconds > 0 {
        summaryItem(
          title: "Peak",
          value: String(format: "%.1f h", p.totalHours),
          subtitle: p.label,
          icon: "star.fill"
        )
        .frame(maxWidth: .infinity)
      }
    }
  }

  private func earningsSummary(data: [ChartDataPoint]) -> some View {
    let periodSuffix = selectedPeriod.isDaily ? "day" : "mo"
    return HStack(spacing: 0) {
      summaryItem(
        title: "Total",
        value: EarningsCalculator.format(totalEarnings(data)),
        icon: "banknote.fill",
        tint: .orange
      )
      .frame(maxWidth: .infinity)

      summaryItem(
        title: "Average",
        value: "\(EarningsCalculator.format(averageEarnings(data)))/\(periodSuffix)",
        icon: "chart.line.uptrend.xyaxis",
        tint: .orange
      )
      .frame(maxWidth: .infinity)

      if let p = peakEarnings(data), p.totalEarnings > 0 {
        summaryItem(
          title: "Peak",
          value: EarningsCalculator.format(p.totalEarnings),
          subtitle: p.label,
          icon: "star.fill",
          tint: .orange
        )
        .frame(maxWidth: .infinity)
      }
    }
  }

  private func jobBreakdownSection(data: [JobBreakdownPoint]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("By Job")
        .font(.headline)

      ForEach(data) { point in
        HStack(spacing: 12) {
          Text(point.jobName)
            .fontWeight(.medium)

          Spacer()

          Text(DurationFormatter.format(point.totalDuration))
            .foregroundColor(.secondary)
            .monospacedDigit()

          Text(EarningsCalculator.format(point.totalEarnings))
            .foregroundColor(.orange)
            .monospacedDigit()
        }
        .font(.callout)
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
