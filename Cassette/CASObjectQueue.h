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
 * A queue of objects. This object should not be allocated directly.
 * It serves as a base implementation for its child classes.
 */
@interface CASObjectQueue<T: id<NSCoding>> : NSObject

/**
 * Adds an element to the end of the queue.
 *
 * Please use the API @c add:error: instead.
 */
- (void)add:(T)data __attribute__((deprecated("Use -add:error: instead.")));

/**
 * Adds an element to the end of the queue.
 * Returns YES on success. On failure, returns NO and sets *error to the error.
 */
- (BOOL)add:(T)data error:(NSError * __autoreleasing * _Nullable)error;

/**
 * Returns the number of elements in this queue.
 */
- (NSUInteger)size;

/**
 * Returns true if this queue contains no entries.
 */
- (BOOL)isEmpty;

/**
 * Returns the head of the queue, or nil if the queue is empty. Does not modify the
 * queue.
 *
 * Please use the API @c peek:error: instead.
 */
- (nullable T)peek __attribute__((deprecated("Use -peek:error: instead.")));

/**
 * Reads up to the specified amount of entries from the head of the queue without removing
 * the entries.
 * If the queue's @c size() is less than the amount specified, then only @c size() entries
 * are read.
 *
 * Please use the API @c peek:error: instead.
 */
- (NSArray<T> *)peek:(NSUInteger)amount __attribute__((deprecated("Use -peek:error: instead.")));

/**
 * Reads up to the specified amount of entries from the head of the queue without removing
 * the entries.
 * If the queue's @c size() is less than the amount specified, then only @c size() entries
 * are read.
 *
 * Returns the items read on success. On failure, returns nil and sets *error to the error.
 */
- (NSArray<T> * _Nullable)peek:(NSUInteger)amount error:(NSError * __autoreleasing * _Nullable)error;

/**
 * Removes the head of the queue.
 *
 * Please use the API @c pop:error: instead.
 */
- (void)pop __attribute__((deprecated("Use -pop:error: instead.")));;

/**
 * Removes the specified amount of entries from the head of the queue.
 *
 * Please use the API @c pop:error: instead.
 */
- (void)pop:(NSUInteger)amount __attribute__((deprecated("Use -peek:error: instead.")));

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
- (void)clear __attribute__((deprecated("Use -clearAndReturnError: instead.")));;

/**
 * Clears this queue. Truncates the file to the initial size.
 * Returns YES on success. On failure, returns NO and sets *error to the error.
 */
- (BOOL)clearAndReturnError:(NSError * __autoreleasing * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
