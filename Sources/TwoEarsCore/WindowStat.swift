public enum Attribution: String, Codable, Sendable, CaseIterable {
    case user, room, uncertain
}

/// One 100 ms analysis window. Everything downstream derives from these; no audio survives.
public struct WindowStat: Equatable, Sendable {
    public var index: Int
    public var startMs: Int
    public var levelDb: Double
    public var noiseFloorDb: Double
    public var zcr: Double
    public var voiced: Bool
    /// nil when unvoiced.
    public var attribution: Attribution?

    public init(index: Int, startMs: Int, levelDb: Double, noiseFloorDb: Double,
                zcr: Double, voiced: Bool, attribution: Attribution?) {
        self.index = index
        self.startMs = startMs
        self.levelDb = levelDb
        self.noiseFloorDb = noiseFloorDb
        self.zcr = zcr
        self.voiced = voiced
        self.attribution = attribution
    }
}
