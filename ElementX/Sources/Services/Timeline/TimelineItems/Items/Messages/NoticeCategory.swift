import Foundation

enum NoticeCategoryType {
    case weather(weatherData: String?) // Weather content
    case basic // Default content type
}

extension NoticeCategoryType: Equatable {
    // Equatable conformance of NoticeCategoryType
    static func == (lhs: NoticeCategoryType, rhs: NoticeCategoryType) -> Bool {
        switch (lhs, rhs) {
        case (.weather(let lhsData), .weather(let rhsData)):
            return lhsData == rhsData // Compare associated values
        case (.basic, .basic):
            return true
        default:
            return false
        }
    }

    /// Function to compute the notice content type based on json parameters
    static func computeContentType(_ input: String?) -> NoticeCategoryType {
        // Default to .basic if input is nil
        guard let inputData = input else { return .basic }

        do {
            // Default to .basic if jsonData is nil
            guard let jsonData = inputData.data(using: .utf8) else { return .basic }
            // Deserialize Data into a JSON object
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any] {
                // If JSON object has weather key then return weather data
                if let contentDict = (jsonObject["content"] as? [String: Any]), contentDict.keys.contains("weather") {
                    return .weather(weatherData: contentDict["weather"] as? String)
                }
            } else {
                // Default to .basic if key not available
                return .basic
            }
        } catch {
            // Handle errors in deserialization
            MXLog.error("Error assigning notice category for the data sent.")
        }
        return .basic
    }
}
