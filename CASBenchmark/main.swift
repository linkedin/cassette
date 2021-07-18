import Cassette
import CollectionsBenchmark
import Foundation

// Benchmark for Cassette library using Apple's Swift Collections Benchmark
// library: https://github.com/apple/swift-collections-benchmark

var benchmark = Benchmark(title: "CASFileObjectQueue")

benchmark.addSimple(
  title: "Invoke add(value) N times",
  input: [Int].self
) { input in
    let uuid = UUID().uuidString
    let queuePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(uuid)
    do {
        let queue = try CASFileObjectQueue<NSNumber>(absolutePath: queuePath.path)
        for value in input {
            // The `error:` parameter would normally be stripped when Swift translates
            // -[CASObjectQueue add:error:] to Swift, but that would conflict with
            // -[CASObjectQueue add:], so it includes the dummy parameter.
            try queue.add(value as NSNumber, error:())
        }
    } catch {
        fatalError("Could not add elements to queue: \(error)")
    }
}

benchmark.main()
