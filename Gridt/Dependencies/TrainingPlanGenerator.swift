import ComposableArchitecture
import Foundation

@DependencyClient
struct TrainingPlanGenerator: Sendable {
    var generatePlan: @Sendable (_ goal: GoalSnapshot) async throws -> TrainingPlanSnapshot
}

extension TrainingPlanGenerator: DependencyKey {
    static let liveValue = TrainingPlanGenerator(
        generatePlan: { goal in
            if goal.planType == .aiAssisted {
                return try await generateAIPlan(goal: goal)
            }

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let raceDay = calendar.startOfDay(for: goal.raceDate)

            let totalDays = calendar.dateComponents([.day], from: today, to: raceDay).day ?? 0
            let totalWeeks = max(3, min(24, totalDays / 7))

            // Phase split: base ~40%, speed ~40%, taper ~20% (min 1 week, max 3)
            let taperWeeks = max(1, min(3, totalWeeks / 5))
            let remainingWeeks = totalWeeks - taperWeeks
            let baseWeeks = remainingWeeks / 2
            let speedWeeks = remainingWeeks - baseWeeks

            // Calculate paces from target time
            let racePacePerKm: Double
            if let targetTime = goal.targetTimeSeconds {
                racePacePerKm = targetTime / (goal.raceDistance.meters / 1000)
            } else {
                // Default paces based on distance
                switch goal.raceDistance {
                case .fiveK: racePacePerKm = 330 // 5:30/km
                case .tenK: racePacePerKm = 345 // 5:45/km
                case .halfMarathon: racePacePerKm = 360 // 6:00/km
                case .marathon: racePacePerKm = 375 // 6:15/km
                }
            }

            let easyPace = racePacePerKm + 60
            let tempoPace = racePacePerKm
            let intervalPace = racePacePerKm - 20
            let longRunPace = racePacePerKm + 40

            // Determine training days
            let trainingDays = goal.trainingDaysPerWeek
            let preferredDays = goal.preferredWeekdays.isEmpty
                ? Set(Weekday.allCases.prefix(trainingDays))
                : goal.preferredWeekdays

            // Build weekly schedule template
            func weekdaysForTraining() -> [Weekday] {
                let blocked = goal.blockedWeekdays
                let available = Weekday.allCases.filter { !blocked.contains($0) }

                if available.count <= trainingDays {
                    return Array(available)
                }

                // Prefer selected days, fill remaining from available
                var selected = Array(preferredDays.filter { !blocked.contains($0) })
                let remaining = available.filter { !selected.contains($0) }

                while selected.count < trainingDays && !remaining.isEmpty {
                    let idx = selected.count - preferredDays.count
                    if idx >= 0 && idx < remaining.count {
                        selected.append(remaining[idx])
                    } else {
                        break
                    }
                }

                return Array(selected.prefix(trainingDays)).sorted { $0.rawValue < $1.rawValue }
            }

            let scheduledDays = weekdaysForTraining()

            // Long run day: prefer weekend (Saturday/Sunday)
            let longRunDay: Weekday = {
                if scheduledDays.contains(.sunday) { return .sunday }
                if scheduledDays.contains(.saturday) { return .saturday }
                return scheduledDays.last ?? .saturday
            }()

            // Base distances
            let raceDistanceKm = goal.raceDistance.meters / 1000
            let startingLongRunKm = raceDistanceKm * 0.5
            let maxLongRunKm = raceDistanceKm * 0.85

            var workouts: [PlannedWorkoutSnapshot] = []
            var sortOrder = 0

            for weekIndex in 0..<totalWeeks {
                let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: today)!

                // Determine phase
                let phase: TrainingPhase
                if weekIndex < baseWeeks {
                    phase = .base
                } else if weekIndex < baseWeeks + speedWeeks {
                    phase = .speed
                } else {
                    phase = .taper
                }

                // Volume progression
                let progressFraction: Double
                if phase == .taper {
                    let taperWeek = weekIndex - (baseWeeks + speedWeeks)
                    progressFraction = max(0.4, 1.0 - Double(taperWeek + 1) * 0.2)
                } else {
                    progressFraction = min(1.0, 0.6 + Double(weekIndex) * 0.1 / Double(max(1, totalWeeks - taperWeeks)))
                }

                // Long run distance for this week
                let longRunProgressFraction = Double(weekIndex) / Double(max(1, baseWeeks + speedWeeks - 1))
                let longRunKm: Double
                if phase == .taper {
                    longRunKm = startingLongRunKm
                } else {
                    longRunKm = startingLongRunKm + (maxLongRunKm - startingLongRunKm) * min(1.0, longRunProgressFraction)
                }

                // Determine which quality workout this week
                let useIntervals = weekIndex % 2 == 1 && phase == .speed

                for dayOfWeek in Weekday.allCases {
                    guard let dayDate = dateForWeekday(dayOfWeek, in: weekStart, calendar: calendar) else { continue }
                    guard dayDate <= raceDay else { continue }
                    guard dayDate >= today else { continue }

                    let isTrainingDay = scheduledDays.contains(dayOfWeek)

                    if !isTrainingDay {
                        workouts.append(PlannedWorkoutSnapshot(
                            id: UUID(),
                            date: dayDate,
                            workoutType: .restDay,
                            descriptionText: "Recovery day",
                            targetDistanceMeters: nil,
                            targetPaceSecondsPerKm: nil
                        ))
                        sortOrder += 1
                        continue
                    }

                    let workout: PlannedWorkoutSnapshot
                    if dayOfWeek == longRunDay {
                        // Long run
                        let distance = longRunKm * progressFraction * 1000
                        workout = PlannedWorkoutSnapshot(
                            id: UUID(),
                            date: dayDate,
                            workoutType: .longRun,
                            descriptionText: "Long run — build endurance at comfortable pace",
                            targetDistanceMeters: distance,
                            targetPaceSecondsPerKm: longRunPace
                        )
                    } else if isQualityDay(dayOfWeek, longRunDay: longRunDay, scheduledDays: scheduledDays) {
                        if useIntervals {
                            let distance = raceDistanceKm * 0.3 * progressFraction * 1000
                            workout = PlannedWorkoutSnapshot(
                                id: UUID(),
                                date: dayDate,
                                workoutType: .intervals,
                                descriptionText: "Speed intervals — alternate fast and recovery segments",
                                targetDistanceMeters: distance,
                                targetPaceSecondsPerKm: intervalPace
                            )
                        } else {
                            let distance = raceDistanceKm * 0.4 * progressFraction * 1000
                            workout = PlannedWorkoutSnapshot(
                                id: UUID(),
                                date: dayDate,
                                workoutType: .tempo,
                                descriptionText: "Tempo run — sustained effort at race pace",
                                targetDistanceMeters: distance,
                                targetPaceSecondsPerKm: tempoPace
                            )
                        }
                    } else {
                        // Easy run
                        let distance = raceDistanceKm * 0.3 * progressFraction * 1000
                        workout = PlannedWorkoutSnapshot(
                            id: UUID(),
                            date: dayDate,
                            workoutType: .easyRun,
                            descriptionText: "Easy run — conversational pace",
                            targetDistanceMeters: distance,
                            targetPaceSecondsPerKm: easyPace
                        )
                    }

                    workouts.append(workout)
                    sortOrder += 1
                }
            }

            return TrainingPlanSnapshot(
                id: UUID(),
                goalId: goal.id,
                workouts: workouts,
                createdAt: Date()
            )
        }
    )

    static let previewValue = TrainingPlanGenerator(
        generatePlan: { goal in
            TrainingPlanSnapshot(
                id: UUID(),
                goalId: goal.id,
                workouts: [],
                createdAt: Date()
            )
        }
    )
}

// MARK: - Helpers

private enum TrainingPhase {
    case base, speed, taper
}

private func dateForWeekday(_ weekday: Weekday, in weekStart: Date, calendar: Calendar) -> Date? {
    // weekStart is a Monday (or the start of the training)
    let currentWeekday = calendar.component(.weekday, from: weekStart) // Sun=1, Mon=2...Sat=7
    let currentMondayBased = currentWeekday == 1 ? 6 : currentWeekday - 2 // Mon=0...Sun=6
    let targetMondayBased = weekday.rawValue - 1 // Mon=0...Sun=6
    let offset = targetMondayBased - currentMondayBased
    return calendar.date(byAdding: .day, value: offset, to: weekStart)
}

private func isQualityDay(_ day: Weekday, longRunDay: Weekday, scheduledDays: [Weekday]) -> Bool {
    // The first non-long-run training day that's ~midweek
    let nonLongRunDays = scheduledDays.filter { $0 != longRunDay }
    guard !nonLongRunDays.isEmpty else { return false }
    // Pick the day closest to the middle of the week
    let midweek = nonLongRunDays[nonLongRunDays.count / 2]
    return day == midweek
}

extension DependencyValues {
    var trainingPlanGenerator: TrainingPlanGenerator {
        get { self[TrainingPlanGenerator.self] }
        set { self[TrainingPlanGenerator.self] = newValue }
    }
}
