//
//  XTRestLayerConnection.m
//  XTRestLayerDemo
//
//  Created by Berik Visschers on 2013-02-25.
//  Copyright (c) 2013 Xaton. All rights reserved.
//

#import "XTRestLayerConnection.h"

@implementation XTRestLayerConnection
@synthesize request=_request;
@synthesize response=_response;
@synthesize responseData=_responseData;
@synthesize responseError=_responseError;
@synthesize completionHandler=_completionHandler;
@synthesize mapperError=_mapperError;
@synthesize parsedResponse=_parsedResponse;
@synthesize numberOfAttempts = _numberOfAttempts;
@synthesize mapper = _mapper;
@synthesize cachingHandler = _cachingHandler;
@synthesize isCached = _isCached;

+ (instancetype)sendAsynchronousRequest:(NSURLRequest *)request
                                 mapper:(id<XTRestLayerMapperProtocol>)mapper
                      connectionHandler:(XTLayerConnectionHandler)connectionHandler
                      completionHandler:(XTLayerConnectionCompletionHandler)completionHandler {
    XTRestLayerConnection *connection = [[self alloc] init];
    connection.request = request;
    connection.mapper = mapper;
    connection.completionHandler = completionHandler;
    if (connectionHandler) {
        connectionHandler(connection);
    }
    [connection start];
    return connection;
}

- (id)init {
    self = [super init];
    if (self) {
        // Rethink this..
        self.queue = [NSOperationQueue mainQueue];
        self.numberOfAttempts = 0;
    }
    return self;
}

- (void)start {
    NSAssert(self.request != nil, @"Request should be set before starting");
    NSAssert(self.queue != nil, @"Queue should be set before starting");
    NSAssert(self.mapper != nil, @"Mapper should be set before starting");
    
    self.numberOfAttempts++;
    [NSURLConnection sendAsynchronousRequest:self.request
                                       queue:self.queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               [self updateWithResponse:response data:data error:error];
                               [self processResponse];
                           }];
}

- (void)cancel {
    NSLog(@"XTRestLayerConnection can not be canceled");
}

#pragma mark - Public methods

- (void)processResponse {
    
    //Apply mapping
    [self.mapper mapDataFromConnection:self completionHandler:^(id results, NSError *error) {
        self.mapperError = error;
        
        //Completion block
        if (self.completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.completionHandler(results, self);
            });
        }
    }];
}

#pragma mark - Private methods

- (void)updateWithResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error {
    NSAssert(error || [response isKindOfClass:[NSHTTPURLResponse class]], @"Response should be HTTP");
    self.response = (NSHTTPURLResponse *)response;
    self.responseData = data;
    self.responseError = error;
}


#pragma mark - Properties

- (id)parsedResponse {
    if (!_parsedResponse){
        
        //Parse JSON (consider invalid JSON as a response error)
        if ([self.responseData length] > 0) {
            NSError *errorJSON = nil;
            _parsedResponse = [NSJSONSerialization JSONObjectWithData:self.responseData
                                                              options:NSJSONReadingMutableContainers
                                                                error:&errorJSON];
            if (errorJSON && !self.responseError) {
                self.responseError = errorJSON;
            }
        }
    }
    return _parsedResponse;
}


- (void)setCachingHandler:(XTLayerConnectionCachingHandler)cachingHandler {
    NSAssert(NO, @"Not implemented");
}

@end
