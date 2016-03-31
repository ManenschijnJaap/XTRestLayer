//
//  XTSessionRestLayerConnection.m
//  XTRestLayerDemo
//
//  Created by Angel Garcia on 17/06/14.
//  Copyright (c) 2014 Xaton. All rights reserved.
//

#import "XTSessionRestLayerConnection.h"

@implementation XTSessionRestLayerConnection
static NSInteger activityCount = 0;
static NSURLSession *sharedSession;

#pragma mark - Public methods
+ (NSURLSession *)sharedSession {
    return sharedSession? sharedSession : [NSURLSession sharedSession];
}

+ (void)setSharedSession:(NSURLSession *)session {
    sharedSession = session;
}

#pragma mark - Overwritten methods

- (void)start {
    NSAssert(self.request != nil, @"Request should be set before starting");
    NSAssert(self.queue != nil, @"Queue should be set before starting");
    NSAssert(self.mapper != nil, @"Mapper should be set before starting");
    
    activityCount++;
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    self.numberOfAttempts++;
    self.sessionTask = [[[self class] sharedSession] dataTaskWithRequest:self.request
                                                       completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                           activityCount--;
                                                           [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:activityCount > 0];
                                                           [self updateWithResponse:response data:data error:error];
                                                           [self processResponse];
                                                       }];
    [self.sessionTask resume];
}

- (void)cancel {
    [self.sessionTask cancel];
}

#pragma mark - Private methods

- (void)updateWithResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error {
    self.response = (NSHTTPURLResponse *)response;
    self.responseData = data;
    
    if (!error) {
        if (![self hasAcceptableStatusCode]) {
            NSInteger statusCode = ([self.response isKindOfClass:[NSHTTPURLResponse class]]) ? [self.response statusCode] : 200;
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            userInfo[NSURLErrorFailingURLErrorKey] = [self.request URL];
            userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:@"HTTP Status code: %ld", (long)statusCode];
            error = [[NSError alloc] initWithDomain:@"XTRestLayer" code:NSURLErrorBadServerResponse userInfo:userInfo];
        }
    }
    self.responseError = error;
}


- (BOOL)hasAcceptableStatusCode {
	if (!self.response) {
		return NO;
	}
    
    NSUInteger statusCode = ([self.response isKindOfClass:[NSHTTPURLResponse class]]) ? (NSUInteger)[self.response statusCode] : 200;
    return ![self acceptableStatusCodes] || [[self acceptableStatusCodes] containsIndex:statusCode];
}

- (NSIndexSet *)acceptableStatusCodes {
    return [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
}


@end
