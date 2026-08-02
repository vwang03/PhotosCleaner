import Foundation

/// Uses capture metadata (time, location) as an additional similarity signal to
/// tighten perceptual-hash/feature-print clustering: visually-similar photos captured
/// far apart in time or space are very unlikely to be true duplicates. Both checks are
/// skip-if-missing — an asset without a creation date or GPS location never gets
/// penalized, since plenty of legitimate photos lack one or both.
public enum MetadataSimilarity {
    /// Returns false only if metadata is present for both assets and clearly
    /// contradicts a duplicate/near-duplicate relationship (too far apart in time or
    /// space for the given sensitivity). Returns true whenever metadata is missing or
    /// consistent.
    public static func isConsistent(
        _ a: ScannedAssetMetadata,
        _ b: ScannedAssetMetadata,
        sensitivity: SimilaritySensitivity
    ) -> Bool {
        if let dateA = a.creationDate, let dateB = b.creationDate {
            let delta = abs(dateA.timeIntervalSince(dateB))
            if delta > sensitivity.maxCaptureTimeIntervalSeconds { return false }
        }

        if let latA = a.latitude, let lonA = a.longitude, let latB = b.latitude, let lonB = b.longitude {
            let distance = haversineDistanceMeters(lat1: latA, lon1: lonA, lat2: latB, lon2: lonB)
            if distance > sensitivity.maxLocationDistanceMeters { return false }
        }

        return true
    }

    /// Great-circle distance between two lat/lon coordinates, in meters.
    public static func haversineDistanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadiusMeters = 6_371_000.0

        let phi1 = lat1 * .pi / 180
        let phi2 = lat2 * .pi / 180
        let deltaPhi = (lat2 - lat1) * .pi / 180
        let deltaLambda = (lon2 - lon1) * .pi / 180

        let sinDeltaPhi = sin(deltaPhi / 2)
        let sinDeltaLambda = sin(deltaLambda / 2)

        let haversine = sinDeltaPhi * sinDeltaPhi
            + cos(phi1) * cos(phi2) * sinDeltaLambda * sinDeltaLambda
        let angularDistance = 2 * atan2(haversine.squareRoot(), (1 - haversine).squareRoot())

        return earthRadiusMeters * angularDistance
    }
}
