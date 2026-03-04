import Foundation

// MARK: - Entry Point

func generateAIPlan(goal: GoalSnapshot) async throws -> TrainingPlanSnapshot {
    let content = try await callOpenAI(prompt: buildPrompt(for: goal))
    return try parseWorkouts(from: content, goal: goal)
}

// MARK: - API Call

private func callOpenAI(prompt: String) async throws -> String {
    let url = URL(string: "https://api.openai.com/v1/chat/completions")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(Secrets.openAIKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 120

    let body: [String: Any] = [
        "model": "gpt-4o-mini",
        "messages": [
            ["role": "system", "content": "You are an expert running coach. Respond only with compact valid JSON, no markdown."],
            ["role": "user", "content": prompt]
        ],
        "response_format": ["type": "json_object"],
        "max_tokens": 16000,
        "temperature": 0.3
    ]

    let bodyData = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
    request.httpBody = bodyData

    print("""
    ── OpenAI REQUEST ──────────────────────────────
    \(String(data: bodyData, encoding: .utf8) ?? "")
    ────────────────────────────────────────────────
    """)

    let (data, response) = try await URLSession.shared.data(for: request)
    let rawResponse = String(data: data, encoding: .utf8) ?? "unreadable"

    print("""
    ── OpenAI RESPONSE ─────────────────────────────
    Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)
    \(rawResponse)
    ────────────────────────────────────────────────
    """)

    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
        throw OpenAIError.httpError(http.statusCode)
    }

    let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
    guard let content = decoded.choices.first?.message.content else {
        throw OpenAIError.emptyResponse
    }
    return content
}

// MARK: - Prompt
// Ask only for training sessions (not rest days) — much smaller response, faster generation.
// Rest days are filled in programmatically after parsing.

private func buildPrompt(for goal: GoalSnapshot) -> String {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"

    let totalDays = calendar.dateComponents([.day], from: today, to: goal.raceDate).day ?? 0
    let weeksUntilRace = totalDays / 7
    let totalSessions = weeksUntilRace * goal.trainingDaysPerWeek

    let targetTimeStr = goal.targetTimeFormatted ?? "no target"
    let preferredStr = goal.preferredWeekdays.isEmpty
        ? "any days"
        : goal.preferredWeekdays.map(\.shortName).sorted().joined(separator: ", ")
    let blockedStr = goal.blockedWeekdays.isEmpty
        ? "none"
        : goal.blockedWeekdays.map(\.shortName).sorted().joined(separator: ", ")

    return """
    Create a \(weeksUntilRace)-week running training plan.

    Race: \(goal.raceDistance.displayName) on \(fmt.string(from: goal.raceDate))
    Target time: \(targetTimeStr)
    Fitness: \(goal.fitnessDescription.isEmpty ? "average runner" : goal.fitnessDescription)
    Training: \(goal.trainingDaysPerWeek) days/week preferred on \(preferredStr), never on \(blockedStr)
    Start: \(fmt.string(from: today))

    IMPORTANT: Output ONLY training sessions — do NOT include rest days or recovery days. Only \(goal.trainingDaysPerWeek) entries per week maximum.

    Return JSON: {"workouts":[{"date":"YYYY-MM-DD","workoutType":"easyRun|longRun|tempo|intervals","descriptionText":"max 5 words","targetDistanceMeters":5000,"targetPaceSecondsPerKm":360}]}

    Periodization: base (weeks 1-\(weeksUntilRace/2)) → speed (weeks \(weeksUntilRace/2+1)-\(weeksUntilRace-2)) → taper (last 2 weeks).
    Long run on weekends. Cutback week every 4 weeks (-20% volume). Paces in seconds/km.
    """
}

// MARK: - Parsing

private func parseWorkouts(from json: String, goal: GoalSnapshot) throws -> TrainingPlanSnapshot {
    print("🤖 OpenAI raw response:\n\(json)")
    guard let data = json.data(using: .utf8) else { throw OpenAIError.parseError }

    let response: WorkoutsResponse
    do {
        response = try JSONDecoder().decode(WorkoutsResponse.self, from: data)
    } catch {
        print("❌ JSON decode error: \(error)")
        throw OpenAIError.parseError
    }
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let raceDay = calendar.startOfDay(for: goal.raceDate)

    // Parse AI training sessions
    var workoutsByDate: [Date: PlannedWorkoutSnapshot] = [:]
    for item in response.workouts {
        guard let date = fmt.date(from: item.date) else { continue }
        let day = calendar.startOfDay(for: date)
        workoutsByDate[day] = PlannedWorkoutSnapshot(
            id: UUID(),
            date: day,
            workoutType: PlannedWorkoutType(rawValue: item.workoutType) ?? .easyRun,
            descriptionText: item.descriptionText,
            targetDistanceMeters: item.targetDistanceMeters,
            targetPaceSecondsPerKm: item.targetPaceSecondsPerKm
        )
    }

    // Fill every remaining day with a rest day
    var allWorkouts: [PlannedWorkoutSnapshot] = []
    var current = today
    while current <= raceDay {
        if let workout = workoutsByDate[current] {
            allWorkouts.append(workout)
        } else {
            allWorkouts.append(PlannedWorkoutSnapshot(
                id: UUID(),
                date: current,
                workoutType: .restDay,
                descriptionText: "Recovery day",
                targetDistanceMeters: nil,
                targetPaceSecondsPerKm: nil
            ))
        }
        current = calendar.date(byAdding: .day, value: 1, to: current)!
    }

    return TrainingPlanSnapshot(id: UUID(), goalId: goal.id, workouts: allWorkouts, createdAt: Date())
}

// MARK: - Models

private struct OpenAIResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: Message
        struct Message: Decodable { let content: String }
    }
}

private struct WorkoutsResponse: Decodable {
    let workouts: [AIWorkout]
}

private struct AIWorkout: Decodable {
    let date: String
    let workoutType: String
    let descriptionText: String
    let targetDistanceMeters: Double?
    let targetPaceSecondsPerKm: Double?
}

// MARK: - Errors

enum OpenAIError: LocalizedError {
    case httpError(Int), emptyResponse, parseError

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "OpenAI request failed (HTTP \(code))"
        case .emptyResponse: return "Empty response from AI"
        case .parseError: return "Failed to parse AI response"
        }
    }
}
