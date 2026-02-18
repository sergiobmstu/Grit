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
            .navigationTitle("Grit")
            .onAppear { store.send(.onAppear) }
            .sheet(
                isPresented: $store.isDatePickerPresented.sending(\.setDatePickerPresented)
            ) {
                GoalDatePickerSheet(
                    currentGoalDate: store.goalDate,
                    onSave: { date in store.send(.setGoalDate(date)) },
                    onCancel: { store.send(.setDatePickerPresented(false)) }
                )
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
                        onDismiss: { store.send(.dismissDetail) }
                    )
                }
            }
        }
    }

    // MARK: - Countdown

    @ViewBuilder
    private var countdownSection: some View {
        if let days = store.daysRemaining, let goal = store.goalDate {
            VStack(spacing: 8) {
                Text("\(days)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)

                Text(days == 1 ? "day left" : "days left")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("Goal: \(goal, format: .dateTime.month(.wide).day().year())")
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
            if store.goalDate != nil {
                HStack(spacing: 12) {
                    Button {
                        store.send(.setDatePickerPresented(true))
                    } label: {
                        Label("Change Goal", systemImage: "calendar")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        store.send(.removeGoal)
                    } label: {
                        Label("Remove", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button {
                    store.send(.setDatePickerPresented(true))
                } label: {
                    Label("Set Goal Date", systemImage: "flag.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }
}

// MARK: - Goal Date Picker Sheet

struct GoalDatePickerSheet: View {
    @State private var selectedDate: Date
    let onSave: (Date) -> Void
    let onCancel: () -> Void

    init(currentGoalDate: Date?, onSave: @escaping (Date) -> Void, onCancel: @escaping () -> Void) {
        let fallback = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        _selectedDate = State(initialValue: currentGoalDate ?? fallback)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            DatePicker(
                "Goal Date",
                selection: $selectedDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(.green)
            .padding()
            .navigationTitle("Set Goal Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(selectedDate) }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Workout Detail Sheet

struct WorkoutDetailSheet: View {
    let date: Date
    let workouts: [WorkoutEntry]
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts",
                        systemImage: "figure.stand",
                        description: Text("No workouts recorded on this day.")
                    )
                } else {
                    List(workouts) { workout in
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

                                Text(formatTimeRange(start: workout.startDate, end: workout.endDate))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
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
        }
    )
}
