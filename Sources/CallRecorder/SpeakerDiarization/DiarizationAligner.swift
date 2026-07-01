import Foundation

struct AlignedSegment: Identifiable, Hashable {
    let id: Int
    let speaker: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

final class DiarizationAligner {
    func align(
        transcriptSegments: [TranscriptSegment],
        speakerSegments: [SpeakerSegment]
    ) -> [AlignedSegment] {
        guard !speakerSegments.isEmpty else {
            return transcriptSegments.enumerated().map { i, seg in
                AlignedSegment(id: i, speaker: "SPEAKER_00", startTime: seg.startTime, endTime: seg.endTime, text: seg.text)
            }
        }

        var result: [AlignedSegment] = []
        for (i, tSeg) in transcriptSegments.enumerated() {
            let speaker = bestSpeaker(for: tSeg, speakers: speakerSegments)
            result.append(AlignedSegment(
                id: i,
                speaker: speaker,
                startTime: tSeg.startTime,
                endTime: tSeg.endTime,
                text: tSeg.text
            ))
        }
        return result
    }

    private func bestSpeaker(for segment: TranscriptSegment, speakers: [SpeakerSegment]) -> String {
        let mid = (segment.startTime + segment.endTime) / 2
        var best = "SPEAKER_00"
        var bestOverlap: TimeInterval = 0

        for sp in speakers {
            let overlapStart = max(segment.startTime, sp.start)
            let overlapEnd = min(segment.endTime, sp.end)
            let overlap = max(0, overlapEnd - overlapStart)

            if overlap > bestOverlap {
                bestOverlap = overlap
                best = sp.speaker
            }
        }

        if bestOverlap <= 0 {
            let closest = speakers.min { abs($0.start - mid) < abs($1.start - mid) }
            best = closest?.speaker ?? "SPEAKER_00"
        }

        return best
    }
}
