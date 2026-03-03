import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    countdownSection
                    calendarSection
                    goalButton
                }
                .padding()
            }
            .navigationTitle("Gridt")
            .onAppear { store.send(.onAppear) }
            .sheet(
                item: $store.scope(state: \.goalSetup, action: \.goalSetup)
            ) { goalSetupStore in
                GoalSetupView(store: goalSetupStore)
                    .presentationDetents([.large])
            }
            .sheet(
                isPresented: Binding(
                    get: { store.selectedDate != nil },
                    set: { if !$0 { store.send(.dismissDetail) } }
                )
            ) {
                if let date = store.selectedDate {
                    WorkoutDetailSheet(
                        date: date,
                        workouts: store.workoutDetails[date] ?? [],
                        plannedWorkouts: store.plannedWorkouts[date] ?? [],
                        onDismiss: { store.send(.dismissDetail) }
                    )
                }
            }
        }
    }

    // MARK: - Countdown

    @ViewBuilder
    private var countdownSection: some View {
        if let days = store.daysRemaining, let goal = store.activeGoal {
            VStack(spacing: 8) {
                Text("\(days)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)

                Text(days == 1 ? "day left" : "days left")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                // Race distance badge
                Text("\(goal.raceDistance.rawValue) \(goal.raceDistance.displayName)")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.15), in: Capsule())

                if let targetTime = goal.targetTimeFormatted {
                    Text("Target: \(targetTime)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("Race: \(goal.raceDate, format: .dateTime.month(.wide).day().year())")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last 30 Days")
                    .font(.headline)
                Spacer()
                if store.isLoading {
                    ProgressView()
                }
            }

            ContributionCalendarView(
                workoutCounts: store.workoutCounts,
                plannedWorkouts: store.plannedWorkouts,
                dayCount: 30,
                onDayTapped: { date in
                    store.send(.selectDate(date))
                }
            )
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Goal Button

    private var goalButton: some View {
        Group {
            if store.activeGoal != nil {
                HStack(spacing: 12) {
                    Button {
                        store.send(.setGoalTapped)
                    } label: {
                        Label("Edit Goal", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        store.send(.removeGoalTapped)
                    } label: {
                        Label("Remove", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button {
                    store.send(.setGoalTapped)
                } label: {
                    Label("Set Running Goal", systemImage: "flag.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }
}

// MARK: - Workout Detail Sheet

struct WorkoutDetailSheet: View {
    let date: Date
    let workouts: [WorkoutEntry]
    let plannedWorkouts: [PlannedWorkoutSnapshot]
    let onDismiss: () -> Void

    private var isFutureDate: Bool {
        date > Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !plannedWorkouts.isEmpty {
                        plannedSection
                    }

                    if !workouts.isEmpty {
                        completedSection
                    }

                    if workouts.isEmpty && plannedWorkouts.isEmpty {
                        ContentUnavailableView(
                            "No Workouts",
                            systemImage: "figure.stand",
                            description: Text("No workouts recorded on this day.")
                        )
                    } else if workouts.isEmpty && !plannedWorkouts.isEmpty && isFutureDate {
                        HStack {
                            Spacer()
                            Label("Upcoming", systemImage: "calendar.badge.clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.secondary.opacity(0.1), in: Capsule())
                            Spacer()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(date.formatted(.dateTime.month(.wide).day().year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Planned Section

    private var plannedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Planned")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(plannedWorkouts) { workout in
                HStack(spacing: 12) {
                    Image(systemName: workout.workoutType.iconName)
                        .font(.title2)
                        .foregroundStyle(colorForWorkoutType(workout.workoutType))
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.workoutType.displayName)
                            .font(.headline)

                        Text(workout.descriptionText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            if let distance = workout.targetDistanceFormatted {
                                Label(distance, systemImage: "ruler")
                            }
                            if let pace = workout.targetPaceFormatted {
                                Label(pace, systemImage: "speedometer")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Completed Section

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Completed")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(workouts) { workout in
                HStack(spacing: 12) {
                    Image(systemName: iconName(for: workout.activityType))
                        .font(.title2)
                        .foregroundStyle(.green)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.activityType)
                            .font(.headline)

                        HStack(spacing: 16) {
                            Label(formatDuration(workout.duration), systemImage: "clock")
                            Label(
                                "\(Int(workout.calories)) kcal",
                                systemImage: "flame"
                            )
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            if let distance = workout.distanceFormatted {
                                Label(distance, systemImage: "ruler")
                            }
                            if let pace = workout.paceFormatted {
                                Label(pace, systemImage: "speedometer")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text(formatTimeRange(start: workout.startDate, end: workout.endDate))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Helpers

    private func colorForWorkoutType(_ type: PlannedWorkoutType) -> Color {
        switch type {
        case .easyRun: .green
        case .longRun: .blue
        case .tempo: .orange
        case .intervals: .red
        case .restDay: .gray
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    private func iconName(for activityType: String) -> String {
        switch activityType {
        case "Running": return "figure.run"
        case "Walking": return "figure.walk"
        case "Cycling": return "figure.outdoor.cycle"
        case "Swimming": return "figure.pool.swim"
        case "Hiking": return "figure.hiking"
        case "Yoga": return "figure.yoga"
        case "Strength Training": return "dumbbell"
        case "Core Training": return "figure.core.training"
        case "HIIT": return "bolt.heart"
        case "Dance": return "figure.dance"
        case "Elliptical": return "figure.elliptical"
        case "Rowing": return "figure.rowing"
        case "Stair Climbing": return "figure.stair.stepper"
        case "Pilates": return "figure.pilates"
        case "Boxing": return "figure.boxing"
        case "Jump Rope": return "figure.jumprope"
        case "Tennis": return "figure.tennis"
        case "Basketball": return "figure.basketball"
        case "Soccer": return "figure.soccer"
        case "Golf": return "figure.golf"
        case "Cross Training": return "figure.cross.training"
        case "Mixed Cardio": return "figure.mixed.cardio"
        default: return "figure.mixed.cardio"
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.healthKitClient = .previewValue
            $0.swiftDataClient = .previewValue
        }
    )
}
