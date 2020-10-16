//
//  TransfoProcessor.h
//  Transfo
//
//  Created by Jamis on 2020/9/16.
//  Copyright © 2020 Jemis. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TransfoManager, TransfoResponse,TransfoRequest,AFHTTPRequestSerializer;


@protocol TransfoResponseProcessor <NSObject>

- (AFHTTPRequestSerializer *)transfo:(TransfoManager *)manager requestSerializer:(TransfoRequest *)request;


- (void)transfo:(TransfoManager *)manager response:(TransfoResponse *)response error:(NSError *)error;


@optional
- (NSString *)transfo:(TransfoManager *)manager absoluteURL:(TransfoRequest *)request;

- (BOOL)transfo:(TransfoManager *)manager shouldStartRequest:(TransfoRequest *)request;


@end


@interface TransfoProcessor : NSObject <TransfoResponseProcessor>

@end

NS_ASSUME_NONNULL_END
