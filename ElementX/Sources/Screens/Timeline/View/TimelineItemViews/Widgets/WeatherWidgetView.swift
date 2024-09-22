import Foundation
import SwiftUI

struct WeatherWidget: View {
    let weatherData: String
    
    @State private var isFahrenheit = false
    
    // Handlers to toggle between Fahrenheit and Celsius
    private func showFahrenheit() {
        isFahrenheit = true
    }
    
    private func showCelsius() {
        isFahrenheit = false
    }

    var body: some View {
        if let weatherData = parseWeatherData(from: weatherData) {
            let location = weatherData.location
            let current = weatherData.current
            let forecast = weatherData.forecast

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        WeatherImage(from: URL(string: "https:" + current.condition.icon)!, width: 64, height: 64)

                        Text("\(isFahrenheit ? "\(current.temp_f)°F" : "\(current.temp_c)°C")")
                            .font(.title2)
                            .fontWeight(.bold)
                    
                        Text(current.condition.text)
                    
                        HStack {
                            Button(action: showFahrenheit) {
                                Text("F")
                                    .foregroundColor(isFahrenheit ? .white : .gray)
                            }
                            Button(action: showCelsius) {
                                Text("C")
                                    .foregroundColor(isFahrenheit ? .gray : .white)
                            }
                        }
                    }
                
                    Spacer()
                
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(location.name)")
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(location.country)")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(DateFormatter.localizedString(from: DateFormatter.date(from: weatherData.location.localtime) ?? Date(), dateStyle: .short, timeStyle: .none))
                                Text(DateFormatter.localizedString(from: DateFormatter.date(from: weatherData.location.localtime) ?? Date(), dateStyle: .none, timeStyle: .short))
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            
                Divider()
            
                HStack(spacing: 4) {
                    ForEach(forecast.forecastday, id: \.date) { day in
                        VStack(alignment: .center, spacing: 8) {
                            WeatherImage(from: URL(string: "https:" + day.day.condition.icon)!, width: 30, height: 30)
                        
                            Text(dayOfWeek(from: day.date))
                                .font(.caption)
                        
                            Text("\(isFahrenheit ? "\(day.day.maxtemp_f)°F / \(day.day.mintemp_f)°F" : "\(day.day.maxtemp_c)°C / \(day.day.mintemp_c)°C")")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Asset.Colors.weatherBackground.swiftUIColor)
            .foregroundColor(Color.white)
            .cornerRadius(10)
        }
    }

    private func parseWeatherData(from jsonString: String) -> WeatherData? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        do {
            let weatherData = try JSONDecoder().decode(WeatherData.self, from: jsonData)
            return weatherData
        } catch {
            MXLog.error("Error decoding weather data: \(error)")
            return nil
        }
    }
    
    private func WeatherImage(from url: URL, width: CGFloat, height: CGFloat) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .frame(width: width, height: height)
            case .failure:
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
                    .frame(width: width, height: height)
            case .empty:
                ProgressView()
                    .frame(width: width, height: height)
            @unknown default:
                Image(systemName: "photo")
                    .resizable()
                    .frame(width: width, height: height)
            }
        }
    }

    // Defining a DateFormatter to get the day of the week
    private func dayOfWeek(from dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd" // Assuming the date format, adjust if different

        // Convert the string to a Date object
        guard let date = dateFormatter.date(from: dateString) else {
            return "" // Return an empty string if the date conversion fails
        }

        // Create another DateFormatter to get the day of the week
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE" // To get full name of the day of the week

        return dayFormatter.string(from: date)
    }
}

// Helper extension for DateFormatter
extension DateFormatter {
    static func date(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: string)
    }
}

// Defining the WeatherData model
struct WeatherData: Codable {
    let location: Location
    let current: Current
    let forecast: Forecast

    struct Location: Codable {
        let name: String
        let country: String
        let localtime: String
    }

    struct Current: Codable {
        let temp_c: Double
        let temp_f: Double
        let condition: Condition

        struct Condition: Codable {
            let text: String
            let icon: String
        }
    }

    struct Forecast: Codable {
        let forecastday: [ForecastDay]

        struct ForecastDay: Codable {
            let date: String
            let day: Day

            struct Day: Codable {
                let condition: Condition
                let maxtemp_c: Double
                let mintemp_c: Double
                let maxtemp_f: Double
                let mintemp_f: Double

                struct Condition: Codable {
                    let icon: String
                }
            }
        }
    }
}
