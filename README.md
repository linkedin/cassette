# Cassette 

Cassette is a collection of queue-related classes for iOS and OSX. It is maintained by [LinkedIn](https://engineering.linkedin.com/). Cassette was originally implemented by [Segment](https://segment.com). Cassette was inspired by [Tape](https://github.com/square/tape).

Currently Cassette consists solely of `QueueFile`.

`QueueFile` is a lightning-fast, file-based FIFO queue. Addition and removal from an instance is an O(1) operation. Writes are synchronous; data will be written to disk before an operation returns.

*note*: The current implementation will simply clear (read: drop) all data in case of a process or system crash. While this is reasonable for some cases (such as analytics data), this makes it less suited to other tasks (such as  payment data).

## Installing the Library

#### CocoaPods
`pod 'Cassette', '~> 0.1.0'`

#### Manual
Download the [latest binary](https://github.com/linkedin/cassette/releases) of the library.

## Usage
* Add the `Cassette` library to your project.

