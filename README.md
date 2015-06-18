# Cassette 

Cassette is a collection of queue-related classes for iOS and OSX by [Segment](https://segment.com). Cassette was inspired by [Tape](https://github.com/square/tape).

Currently Cassette consists solely of `QueueFile`.

`QueueFile` is a lightning-fast, file-based FIFO queue. Addition and removal from an instance is an O(1) operation. Writes are synchronous; data will be written to disk before an operation returns.

*note*: The current implementation will simply clear (read: drop) all data in case of a process or system crash. While this is reasonable for some cases (such as analytics data), this makes it less suited to other tasks (such as  payment data).

## Installing the Library

#### CocoaPods
`pod 'Cassette', '~> 0.1.0'`

#### Manual
Download the [latest binary](https://github.com/segmentio/cassette/releases) of the library.

## Usage
* Add the `Cassette` library to your project.


## License

```
WWWWWW||WWWWWW
 W W W||W W W
      ||
    ( OO )__________
     /  |           \
    /o o|    MIT     \
    \___/||_||__||_|| *
         || ||  || ||
        _||_|| _||_||
       (__|__|(__|__|


(The MIT License)

Copyright (c) 2015 Segment Inc. <friends@segment.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
