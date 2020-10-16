//
//  TransfoResponse.h
//  Transfo
//
//  Created by Jamis on 2020/9/2.
//  Copyright © 2020 Jemis. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TransfoRequest;
NS_ASSUME_NONNULL_BEGIN

@interface TransfoResponse : NSObject

@property (nonatomic, strong)TransfoRequest * request;

@property (nonatomic, assign)NSInteger statusCode;

@property (nonatomic, assign)BOOL status;

@property (nullable,    copy) NSDictionary<NSString *, NSString *> * HTTPHeaderFields;

@property (nonatomic,   copy)id responseObject;

@property (nonatomic, strong)NSError  * error;
@property (nonatomic,   copy)NSString * errorMsg;

@property (nonatomic, strong)id errorInfo;


@end

NS_ASSUME_NONNULL_END
