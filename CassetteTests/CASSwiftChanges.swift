//
//  CASSwiftChanges.swift
//  CassetteTests
//
//  Created by Alfons Hoogervorst on 05/08/2021.
//

import XCTest
import Cassette

class CASSwiftChanges: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    fileprivate func testOperations(with queue: CASObjectQueue<NSNumber>) {
        try? queue.add(1)
        try? queue.add(2)
        try? queue.add(3)
        XCTAssert(queue.size() == 3, "Should contain 3 elements")
        try? queue.pop(1)
        let secondValue = try? queue.peek()
        XCTAssert(secondValue == 2, "Should be value 2")
        try? queue.clear()
        XCTAssert(queue.size() == 0, "Should have zero items")
        try? queue.add(NSNumber(integerLiteral: 2))
        XCTAssert(queue.size() == 1, "Should have 1 item")
        try? queue.clear()
        XCTAssert(queue.size() == 0, "Should have zero items")
        try? queue.add(4)
        let fourthValue = try? queue.peek()
        XCTAssert(fourthValue == 4, "Should be value 4")
        try? queue.pop(1)
        XCTAssertThrowsError(try queue.peek(), "Should throw an error")
    }

    func testChangesCASInMemoryQueue() throws {
        let queue = CASInMemoryObjectQueue<NSNumber>()
        self.testOperations(with: queue)
    }
    
    func testChangesCASFileObjectQueue() throws {
        let queueFileName = "\(NSTemporaryDirectory())/\(UUID().uuidString)"
        // remove old remnants
        try? FileManager.default.removeItem(atPath: queueFileName)
        let queue = try? CASFileObjectQueue<NSNumber>(absolutePath: queueFileName)
        XCTAssertNotNil(queue)
        self.testOperations(with: queue!)
    }

    func testChangesCASFileObjectQueueReopen() throws {
        let queueFileName = "\(NSTemporaryDirectory())/\(UUID().uuidString)"
        // remove old remnants
        try? FileManager.default.removeItem(atPath: queueFileName)
        let queue = try? CASFileObjectQueue<NSNumber>(absolutePath: queueFileName)
        XCTAssertNotNil(queue)
        self.testOperations(with: queue!)
        try? queue?.add(5)
        XCTAssertNoThrow(try queue?.close())
        let reopenedQueue = try? CASFileObjectQueue<NSNumber>(absolutePath: queueFileName)
        XCTAssertNotNil(reopenedQueue)
        let value = try? reopenedQueue?.peek(5)
        XCTAssertNotNil(value)
        XCTAssert(value!.count == 1, "Array with one element")
        XCTAssertNoThrow(try reopenedQueue?.pop(1))
        XCTAssert(reopenedQueue!.size() == 0, "Should now have no contents.")
        XCTAssert(value!.first == 5, "Value should be 5")
    }

}
