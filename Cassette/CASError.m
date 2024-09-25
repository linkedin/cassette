//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and limitations under the License.

#import "CASError.h"

NSString * const CASErrorDomain = @"com.linkedin.LITape.ErrorDomain";
const int CASErrorCode = -7493;

@implementation CASError

+ (NSError *)createError:(CASErrorType)type {
    return [NSError errorWithDomain:CASErrorDomain code:CASErrorCode userInfo:[self userInfo:type]];
}

+ (BOOL)handleError:(nullable NSError *)casError error:(NSError * __autoreleasing *)error {
    if (casError) {
        if (error) {
            *error = casError;
        }
        return true;
    }

    return false;
}

+ (NSDictionary *)userInfo:(CASErrorType)type {
    NSString *desc;
    switch (type) {
        case CASErrorFileInitialization:
            desc = @"Could not initialize file.";
            break;
        case CASErrorReadErrorFileTooShort:
            desc = @"Read error (file too short)";
            break;
        default:
            desc = @"Unknown Cassette error. Developer likely mistakenly applied this as a Cassette error.";
            break;
    }
    return @{ NSLocalizedDescriptionKey : desc };
}

@end
