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
                dayCount: 30
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
