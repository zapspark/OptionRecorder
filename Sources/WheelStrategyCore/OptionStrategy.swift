import Foundation

public enum OptionStrategy: String, Codable, CaseIterable, Identifiable {
    case wheel = "Wheel"

    public var id: String { rawValue }
}
