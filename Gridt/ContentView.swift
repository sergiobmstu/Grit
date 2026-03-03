import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    countdownSection
                    progressSection
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

    // MARK: - Progress

    @ViewBuilder
    private var progressSection: some View {
        if store.activeGoal != nil, let progress = store.trainingProgress {
            VStack(spacing: 14) {
                // Progress bar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.2))
                            Capsule()
                                .fill(Color.green)
                                .frame(width: geo.size.width * CGFloat(max(0, min(1, progress))))
                        }
                    }
                    .frame(height: 10)

                    HStack {
                        Text("Start")
                        Spacer()
                        Text("\(Int(progress * 100))% complete")
                        Spacer()
                        Text("Goal")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Divider()

                // Stats grid
                HStack(spacing: 12) {
                    statTile(icon: "scope", iconColor: .green, label: "Progress",
                             value: "\(Int(progress * 100))%")
                    statTile(icon: "flame.fill", iconColor: .orange, label: "Streak",
                             value: "\(store.currentStreak) days")
                }
                HStack(spacing: 12) {
                    statTile(icon: "calendar", iconColor: .secondary, label: "Remaining",
                             value: "\(store.daysRemaining ?? 0) days")
                    statTile(icon: "chart.line.uptrend.xyaxis", iconColor: .green, label: "Completed",
                             value: "\(store.completedPlannedWorkouts)/\(store.totalPlannedWorkouts)")
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func statTile(icon: String, iconColor: Color, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(label)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(spacing: 8) {
            if store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            ContributionCalendarView(
                month: store.displayedMonth,
                workoutCounts: store.workoutCounts,
                plannedWorkouts: store.plannedWorkouts,
                onDayTapped: { store.send(.selectDate($0)) },
                onPreviousMonth: { store.send(.previousMonth) },
                onNextMonth: { store.send(.nextMonth) }
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
