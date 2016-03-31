//
//  XTRestLayerMapper.m
//  XTRestLayerDemo
//
//  Created by Berik Visschers on 2013-02-25.
//  Copyright (c) 2013 Xaton. All rights reserved.
//

#import "XTRestLayerMapperBase.h"

@implementation XTRestLayerMapperBase

- (void)mapDataFromConnection:(id<XTRestLayerConnectionProtocol>)connection completionHandler:(XTLayerMapperCompletionHandler)completionHandler {
    NSAssert(NO, @"Needs implementation in subclass");
}

- (Class)modelClassForPath:(NSString *)path {
    NSAssert(NO, @"Needs implementation in subclass");
    return Nil;
}

@end
