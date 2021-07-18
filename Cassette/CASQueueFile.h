//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A reliable, efficient, file-based, FIFO queue. Additions and removals are O(1). All operations
 * are atomic. Writes are synchronous; data will be written to disk before an operation returns.
 * The underlying file is structured to survive process and even system crashes. If an I/O
 * exception is thrown during a mutating change, the change is aborted. It is safe to continue to
 * use a @c CASQueueFile instance after an exception.
 *
 * <p><strong>Note that this implementation is not synchronized.</strong>
 */
@interface CASQueueFile : NSObject

/**
 * The primary way to construct an @c LITapeQueueFile.
 */
+ (nullable CASQueueFile *)queueFileWithPath:(NSString *)path error:(NSError * __autoreleasing * _Nullable)error;

/**
 * Initializing the queue file directly is unavailable.
 * Please use the API @c queueFileWithPath
 */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Adds an element to the end of the queue.
 *
 * Please use the API @c add:error: instead.
 */
- (void)add:(NSData *)data __attribute__((deprecated("Use -add:error: instead.")));

/**
 * Adds an element to the end of the queue.
 * Returns YES on success. On failure, returns NO and sets *error to the error.
 */
- (BOOL)add:(NSData *)data error:(NSError * __autoreleasing * _Nullable)error;

/**
 * Returns the number of elements in this queue.
 */
- (NSUInteger)size;

/**
 * Returns true if this queue contains no entries.
 */
- (BOOL)isEmpty;

/**
 * Reads up to the specified amount of entries from the head of the queue without removing
 * the entries.
 * If the queue's @c size() is less than the amount specified, then only @c size() entries
 * are read.
 *
 * Please use the API @c peek:error: instead.
 */
- (NSArray<NSData *> *)peek:(NSUInteger)amount __attribute__((deprecated("Use peek:error: instead.")));

/**
 * Reads up to the specified amount of entries from the head of the queue without removing
 * the entries.
 * If the queue's @c size() is less than the amount specified, then only @c size() entries
 * are read.
 *
 * Returns the items read on success. On failure, returns nil and sets *error to the error.
 */
- (nullable NSArray<NSData *> *)peek:(NSUInteger)amount error:(NSError * __autoreleasing * _Nullable)error;

/**
 * Removes the specified amount of entries from the head of the queue.
 *
 * Please use the API @c pop:error: instead.
 */
- (void)pop:(NSUInteger)amount __attribute__((deprecated("Use -pop:error: instead.")));

/**
 * Removes the specified amount of entries from the head of the queue.
 * Returns YES on success. On failure, returns NO and sets *error to the error.
 */
- (BOOL)pop:(NSUInteger)amount error:(NSError * __autoreleasing * _Nullable)error;

/**
 * Clears this queue. Truncates the file to the initial size.
 *
 * Please use the API @c clearAndReturnError: instead.
 */
- (void)clear __attribute__((deprecated("Use -clearAndReturnError: instead.")));

/**
 * Clears this queue. Truncates the file to the initial size.
 * Returns YES on success. On failure, returns NO and sets *error to the error.
 */
- (BOOL)clearAndReturnError:(NSError * __autoreleasing * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
