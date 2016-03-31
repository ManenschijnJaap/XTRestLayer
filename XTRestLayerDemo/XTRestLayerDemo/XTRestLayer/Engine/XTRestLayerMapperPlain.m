//
//  XTRestLayerMapperPlain.m
//  XTRestLayerDemo
//
//  Created by Berik Visschers on 2013-02-26.
//  Copyright (c) 2013 Xaton. All rights reserved.
//

#import "XTRestLayerMapperPlain.h"
#import "NSObject+Properties.h"

@implementation XTRestLayerMapperPlain

- (Class)modelClassForPath:(NSString *)path {
    return [self.classMap objectForKey:path];
}

- (void)mapDataFromConnection:(id<XTRestLayerConnectionProtocol>)connection completionHandler:(XTLayerMapperCompletionHandler)completionHandler {
    id response = [self mapResponseChunk:connection.parsedResponse atPath:@""];
    if (completionHandler) {
        completionHandler(response, nil);
    }
}

- (id)mapResponseChunk:(id)responseChunk atPath:(NSString *)path {
    id resultModelObject = nil;
    
    if ([responseChunk isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionaryResponseChunk = (NSDictionary *)responseChunk;

        Class modelClass = [self modelClassForPath:path];
        if (modelClass == Nil) {
            NSLog(@"No class defined for path: '%@'. Using NSDictionary instead", path);
            
            NSMutableDictionary *resultDictionary = [NSMutableDictionary dictionaryWithCapacity:dictionaryResponseChunk.allKeys.count];
            for (NSString *key in dictionaryResponseChunk.allKeys) {
                id mapResult = [self mapResponseChunk:dictionaryResponseChunk[key] atPath:[path stringByAppendingString:key]];
                if (mapResult != nil) {
                    resultDictionary[key] = mapResult;
                }
            }
                        
            resultModelObject = [NSDictionary dictionaryWithDictionary:resultDictionary];
        } else {
            resultModelObject = [self mapDictionaryResponseChunk:dictionaryResponseChunk toClass:modelClass path:path];
        }
    } else if ([responseChunk isKindOfClass:[NSArray class]]) {
        NSArray *responseChunkArray = (NSArray *)responseChunk;
        NSMutableArray *modelObjectArray = [NSMutableArray arrayWithCapacity:responseChunkArray.count];
        for (id chunk in responseChunkArray) {
            id modelObject = [self mapResponseChunk:chunk atPath:[path stringByAppendingString:@"@"]];
            if (modelObject) {
                [modelObjectArray addObject:modelObject];
            } else {
                // handle mapping of chunk failed
            }
        }
        resultModelObject = [NSArray arrayWithArray:modelObjectArray];
    }
    
    return resultModelObject;
}

- (id)mapDictionaryResponseChunk:(NSDictionary *)responseChunk toClass:(Class)modelClass path:(NSString *)path {
    id modelObject = [[modelClass alloc] init];
    
    for (NSString *propertyName in [modelObject propertyNames]) {
        id propertyValue = responseChunk[propertyName];
        
        if (propertyValue == nil) {
            // handle nil value setter
            continue;
        }
        
        NSString *newPath = [path stringByAppendingString:propertyName];
        const char *propertyType = [modelObject typeOfPropertyNamed:propertyName];
        
        size_t type_length = strlen(propertyType);
        if (type_length < 2) {
            continue;
        }
        
        NSString *classNameTo = nil;
        const char baseType = propertyType[1];
        switch (baseType) {
            case '@': {
                if (type_length > 4) {
                    const char *quote = "\"";
                    char *start = strstr(propertyType, quote);
                    start++;
                    char *end = strstr(start, quote);
                    classNameTo = [[NSString alloc] initWithBytes:start length:(end - start) encoding:NSUTF8StringEncoding];
                } else {
                    NSLog(@"Strange type found: %s", propertyType);
                }
                break;
            }
            case '*':
            case '#':
            case ':':
            case '[':
            case '{':
            case '(':
            case 'b':
            case '^':
            case '?': {
                // what to do
                break;
            }
            default: {
                classNameTo = [[NSString alloc] initWithBytes:&baseType length:1 encoding:NSASCIIStringEncoding];
                break;
            }
        }
        
        void *memoryToRelease = NULL;
        void *argumentPointer = NULL;
        void *argument = NULL;

        if ([propertyValue isKindOfClass:[NSArray class]]) {
            // Arrays are forced to map with the chunk mapper
            argument = (__bridge void *)[self mapResponseChunk:propertyValue atPath:newPath];
            argumentPointer = &argument;
        } else {
            NSString *classNameFrom = NSStringFromClass([self classForObject:propertyValue]);
            if (classNameTo != nil && classNameFrom != nil) {
                argumentPointer = [self mapValue:propertyValue
                                   toModelObject:modelObject
                                   fromClassName:classNameFrom
                                     toClassName:classNameTo];
                memoryToRelease = argumentPointer;
            }
        }
        
        if (argumentPointer == NULL) {
            NSLog(@"While mapping property '%@' of '%@', will try mapResponseChunk", propertyName, path);
            argument = (__bridge void *)[self mapResponseChunk:propertyValue atPath:newPath];
            argumentPointer = &argument;
        }
        
        if (argumentPointer == NULL) {
            NSLog(@"Error");
        }
        
        SEL setter = [modelObject setterForPropertyNamed:propertyName];
        NSMethodSignature *signature = [modelObject methodSignatureForSelector:setter];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setSelector:setter];
        [invocation setTarget:modelObject];
        [invocation setArgument:argumentPointer atIndex:2];
        [invocation invoke];

        if (memoryToRelease != NULL) {
            free(memoryToRelease);
        }
    }
    return modelObject;
}

- (void *)mapValue:(id)value
     toModelObject:(id)modelObject
     fromClassName:(NSString *)classNameFrom
       toClassName:(NSString *)classNameTo {

    SEL valueMapperSelector = NSSelectorFromString([NSString stringWithFormat:@"map%@to%@:", classNameFrom, classNameTo]);
    id valueMapper = nil;
    
    if (   [modelObject conformsToProtocol:@protocol(XTRestLayerModelValueMapperProtocol)]
        && [modelObject respondsToSelector:valueMapperSelector]) {
        valueMapper = modelObject;
    } else if ([self respondsToSelector:valueMapperSelector]) {
        valueMapper = self;
    } else {
        NSLog(@"No value mapper found for %s", sel_getName(valueMapperSelector));
        return NULL;
    }
    
    NSLog(@"Value mapping %@ to %@", classNameFrom, classNameTo);
    
    NSMethodSignature *signature = [valueMapper methodSignatureForSelector:valueMapperSelector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:valueMapper];
    [invocation setSelector:valueMapperSelector];
    void *valueMapperArgument = (__bridge void *)value;
    [invocation setArgument:&valueMapperArgument atIndex:2];
    [invocation invoke];
    
    void *valueMapperReturnValue = malloc([signature methodReturnLength]);
    [invocation getReturnValue:valueMapperReturnValue];
    return valueMapperReturnValue;
}

- (Class)classForObject:(NSObject *)object {
    NSArray *classes = @[[NSString class],
                         [NSNumber class],
                         [NSArray class],
                         [NSDictionary class],
                         [NSData class],
                         [NSDate class]];

    for (Class class in classes) {
        if ([object isKindOfClass:class]) {
            return class;
        }
    }
    
    return [object class];
}

- (NSURL *)mapNSStringtoNSURL:(NSString *)string {
    return [NSURL URLWithString:string];
}

- (double)mapNSNumbertod:(NSNumber *)number {
    return [number doubleValue];
}

- (NSString *)mapNSStringtoNSString:(NSString *)string {
    return string;
}

@end
