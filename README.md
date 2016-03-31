XTRestLayer
===========


Install it with Pods:


``` ruby
pod 'XTRestLayer', :podspec => 'https://gist.github.com/angelolloqui/5411668/raw/8c7e46fde7c65b3242c57744c15e8eed434aa73b/XTRestLayer.podspec'

```

And use it:


``` obj-c
    [XTRestLayerConnection sendAsynchronousRequest:request
                                            mapper:mapper
                                 connectionHandler:^(id<XTRestLayerConnectionProtocol> connection) {
                                     //Configure connection
                                     connection.HTTPMethod = @"POST";
                                 } completionHandler:^(id result, id<XTRestLayerConnectionProtocol> connection) {
                                     //Check results
                                     if (connection.mapperError) {
                                         if (errorBlock) {
                                             NSLog(@"error happend: %@", connection.mapperError);
                                         }
                                     }
                                     else {
                                             NSLog(@"success with result: %@", result);
                                     }
                                 }];
```