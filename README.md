[![Build Status](https://dev.azure.com/lnkd-oss/cassette/_apis/build/status/linkedin.cassette?branchName=master)](https://dev.azure.com/lnkd-oss/cassette/_build/latest?definitionId=4&branchName=master)

# Cassette 

Cassette is a collection of queue-related classes for iOS and OSX. It is maintained by [LinkedIn](https://engineering.linkedin.com/). Cassette was originally implemented by [Segment](https://segment.com). Cassette was inspired by [Tape](https://github.com/square/tape).

`QueueFile` is a lightning-fast, file-based FIFO queue. Addition and removal from an instance is an O(1) operation. Writes are synchronous; data will be written to disk before an operation returns.

*note*: The current implementation will simply clear (read: drop) all data in case of a process or system crash. While this is reasonable for some cases (such as analytics data), this makes it less suited to other tasks (such as  payment data).

## Installing the Library

#### CocoaPods
```
target 'MyApp' do
  pod 'Cassette', '1.0.0-beta1'
end
```

#### Manual
Download the [latest binary](https://github.com/linkedin/cassette/releases) of the library.

## Usage
`CASObjectQueue` works with arbitrary objects that abide by the [NSCoding](https://developer.apple.com/documentation/foundation/nscoding?language=objc) protocol. An `CASObjectQueue` may be backed by a persistent `CASQueueFile`, or in memory. 

```
CASObjectQueue<NSNumber *> *queue;

// Persistent ObjectQueue
NSError *error;
queue = [[CASFileObjectQueue alloc] initWithRelativePath:@"Test-File" error:&error];

// In-Memory ObjectQueue
queue = [[CASInMemoryObjectQueue alloc] init];
```

Add some data to the end of the queue.
```
[queue add:@1];
```

Read data at the head of the queue.
```
// Peek the eldest element.
NSNumber *data = [queue peek];

// Peek the eldest `n` elements.
NSArray<NSNumber *> *data = [queue peek:n];
```

Remove processed elements.
```
// Remove the eldest element.
[queue pop];

// Remove 'n' elements.
[queue pop:n];

// Remove all elements.
[queue clear];
```
