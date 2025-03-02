import SwiftUI

extension Color {
    static let customDarkNavy = Color(red: 0.05, green: 0.05, blue: 0.15)
    static let customNavy = Color(red: 0.1, green: 0.1, blue: 0.2)
    static let customBeige = Color(red: 0.95, green: 0.95, blue: 0.87)
    static let customAccent = Color(red: 0.4, green: 0.6, blue: 1.0)
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.customNavy)
            .foregroundColor(.customBeige)
            .cornerRadius(12)
    }
}

// Добавляем стили для кнопок
struct CustomButtonStyle: ButtonStyle {
    var foregroundColor: Color = .customDarkNavy
    var backgroundColor: Color = .customBeige
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// Добавляем стиль для списков
struct CustomListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
            .background(Color.customDarkNavy)
    }
}

extension View {
    func customListStyle() -> some View {
        modifier(CustomListStyle())
    }
} 