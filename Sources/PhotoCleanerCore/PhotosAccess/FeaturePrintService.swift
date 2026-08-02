import Foundation
import Vision
import CoreGraphics

/// Generates Vision feature prints for higher-accuracy similarity confirmation, per
/// PRD 6: "Vision framework (`VNGenerateImageFeaturePrintRequest`) ... for higher-
/// accuracy clustering." The serialized `Data` is stored in the cache and later
/// compared via `FeaturePrintMath`, which assumes Float32 elements.
public enum FeaturePrintService {
    public static func generateFeaturePrintData(for cgImage: CGImage) -> Data? {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first as? VNFeaturePrintObservation else { return nil }
            guard observation.elementType == .float else { return nil }
            return observation.data
        } catch {
            return nil
        }
    }
}
