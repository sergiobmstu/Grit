import ComposableArchitecture
import SwiftUI

struct GoalSetupView: View {
    @Bindable var store: StoreOf<GoalSetupFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    raceDistanceSection
                    raceDateSection
                    targetTimeSection
                    fitnessSection
                    trainingDaysSection
                    weekdayPreferencesSection
                    planTypeSection

                    if let error = store.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    createButton
                }
                .padding()
            }
            .navigationTitle(store.existingGoalId != nil ? "Edit Goal" : "Set Running Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.delegate(.dismissed))
                    }
                }
            }
        }
    }

    // MARK: - Race Distance

    private var raceDistanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Race Distance")
                .font(.headline)

            HStack(spacing: 10) {
                ForEach(RaceDistance.allCases, id: \.self) { distance in
                    Button {
                        store.raceDistance = distance
                    } label: {
                        Text(distance.rawValue)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        store.raceDistance == distance ? Color.green : Color.secondary.opacity(0.3),
                                        lineWidth: store.raceDistance == distance ? 2 : 1
                                    )
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(store.raceDistance == distance ? Color.green.opacity(0.1) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Race Date

    private var raceDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Race Date")
                    .font(.headline)
                Spacer()
                if store.weeksUntilRace > 0 {
                    Text("\(store.weeksUntilRace) weeks away")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            DatePicker(
                "Race Date",
                selection: $store.raceDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(.green)

            if !store.isValid {
                Text("Race must be at least 3 weeks away")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Target Time

    private var targetTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target Time")
                .font(.headline)

            Text("Optional — helps set training paces")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("e.g., 3:30:00 or 25:00", text: $store.targetTimeText)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numbersAndPunctuation)
        }
    }

    // MARK: - Fitness Description

    private var fitnessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Fitness")
                .font(.headline)

            Text("Optional — describe where you are now")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $store.fitnessDescription)
                .frame(minHeight: 60)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if store.fitnessDescription.isEmpty {
                        Text("e.g., I can run 5K comfortably...")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Training Days

    private var trainingDaysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Training Days per Week")
                .font(.headline)

            Stepper(
                "\(store.trainingDaysPerWeek) days",
                value: $store.trainingDaysPerWeek,
                in: 3...7
            )
            .padding(.vertical, 4)
        }
    }

    // MARK: - Weekday Preferences

    private var weekdayPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekday Preferences")
                .font(.headline)

            Text("Tap to prefer (green) or block (red) days")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Button {
                        if store.blockedWeekdays.contains(day) {
                            store.send(.toggleBlockedWeekday(day))
                        } else if store.preferredWeekdays.contains(day) {
                            store.send(.togglePreferredWeekday(day))
                            store.send(.toggleBlockedWeekday(day))
                        } else {
                            store.send(.togglePreferredWeekday(day))
                        }
                    } label: {
                        Text(day.singleLetter)
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(weekdayColor(for: day))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(weekdayBorderColor(for: day), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(Color.green.opacity(0.2)).frame(width: 8, height: 8)
                    Text("Preferred").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.red.opacity(0.2)).frame(width: 8, height: 8)
                    Text("Blocked").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func weekdayColor(for day: Weekday) -> Color {
        if store.preferredWeekdays.contains(day) {
            return .green.opacity(0.2)
        } else if store.blockedWeekdays.contains(day) {
            return .red.opacity(0.2)
        }
        return .secondary.opacity(0.1)
    }

    private func weekdayBorderColor(for day: Weekday) -> Color {
        if store.preferredWeekdays.contains(day) {
            return .green
        } else if store.blockedWeekdays.contains(day) {
            return .red
        }
        return .secondary.opacity(0.3)
    }

    // MARK: - Plan Type

    private var planTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan Type")
                .font(.headline)

            HStack(spacing: 12) {
                // Simple Plan
                Button {
                    store.selectedPlanType = .simple
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                            .font(.title2)
                        Text("Simple Plan")
                            .font(.subheadline.weight(.medium))
                        Text("Template-based")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                store.selectedPlanType == .simple ? Color.green : Color.secondary.opacity(0.3),
                                lineWidth: store.selectedPlanType == .simple ? 2 : 1
                            )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(store.selectedPlanType == .simple ? Color.green.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(.plain)

                // AI-assisted Plan
                VStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                    Text("AI Plan")
                        .font(.subheadline.weight(.medium))
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .opacity(0.5)
            }
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button {
            store.send(.createGoalTapped)
        } label: {
            HStack {
                if store.isGenerating {
                    ProgressView()
                        .tint(.white)
                }
                Text(store.existingGoalId != nil ? "Update Goal & Regenerate Plan" : "Create Goal & Generate Plan")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .disabled(!store.isValid || store.isGenerating)
        .padding(.top, 8)
    }
}
