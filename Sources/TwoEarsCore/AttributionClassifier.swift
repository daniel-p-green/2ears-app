/// Assigns a voiced window to the wearer, the room, or uncertain from its loudness band.
public enum AttributionClassifier {
    public static func classify(levelDb: Double, noiseFloorDb: Double, config: ClassifierConfig) -> Attribution {
        let rel = levelDb - (noiseFloorDb + config.userBandDb)
        if rel >= config.uncertainMarginDb { return .user }
        if rel <= -config.uncertainMarginDb { return .room }
        return .uncertain
    }
}
