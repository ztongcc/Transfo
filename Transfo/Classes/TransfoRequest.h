//
//  TransfoRequest.h
//  Transfo
//
//  Created by Jamis on 2020/9/2.
//  Copyright © 2020 Jemis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TransfoResponse.h"
#import "AFNetworking.h"

NS_ASSUME_NONNULL_BEGIN


///  Request serializer type.
typedef NS_ENUM(NSInteger, TFRequestSerializerType) {
    TFRequestSerializerTypeHTTP = 0,
    TFRequestSerializerTypeJSON,
};


typedef NS_ENUM(NSInteger, TFRequestMethod) {
    TFGET = 0,
    TFPOST,
    TFPUT,
    TFPATCH,
    TFDELETE,
    TFHEAD,
};


typedef void (^AFConstructingBlock)(id<AFMultipartFormData> formData);
typedef void (^AFURLSessionTaskProgressBlock)(NSProgress * progress);

typedef NSDictionary * _Nullable (^TFRequestCustomHeaderFieldValueBlock)(void);

typedef void (^ _Nullable TFRequestHandlerBlock)(TransfoRequest * _Nonnull request);
typedef void (^ _Nullable TFRequestCompletionBlock)(TransfoResponse * _Nonnull response);
typedef void (^ _Nullable TFGroupRequestCompletionBlock)(NSArray <TransfoResponse *>* _Nonnull group);
typedef void (^ _Nullable TFThenRequestHandlerBlock)(NSArray <TransfoResponse *>* _Nonnull group, TransfoRequest * _Nonnull request);



@interface TransfoRequest : NSObject

@property (nonatomic, copy)NSString * _Nonnull api;
// 被替换的占位参数
@property (nonatomic, strong)id _Nullable pathParameter;
// 放在URL 路径后面
@property (nonatomic, strong)id _Nullable queryParameter;
// 放在 HTTP body 里面
@property (nonatomic, strong)id _Nullable bodyParameter;
// 是否需要 Authorization 默认 为 YES
@property (nonatomic, assign)BOOL requireAuthorization;

@property (nonatomic, assign)TFRequestMethod HTTPMethod;

@property (nullable,    weak) NSURLSessionTask * dataTask;

@property (nonatomic, assign)TFRequestSerializerType requestSerializerType;

@property (nonatomic, assign)BOOL barrage;
// 忽略请求返回的结果
@property (nonatomic, assign)BOOL ignore;
// 别名
@property (nonatomic, assign)NSInteger tag;

///  The priority of the request. Default is `NSURLSessionTaskPriorityDefault`.
@property (nonatomic, assign)float priority;

///  This value is used to perform resumable download request. Default is nil.
///
///  @discussion NSURLSessionDownloadTask is used when this value is not nil.
///              The exist file at the path will be removed before the request starts. If request succeed, file will
///              be saved to this path automatically, otherwise the response will be saved to `responseData`
///              and `responseString`. For this to work, server must support `Range` and response with
///              proper `Last-Modified` and/or `Etag`. See `NSURLSessionDownloadTask` for more detail.
@property (nonatomic, strong, nullable) NSString *resumableDownloadPath;


@property (nonatomic, copy)AFConstructingBlock _Nullable constructingBlock;

@property (nonatomic, copy)AFURLSessionTaskProgressBlock _Nullable uploadProgressBlock;
@property (nonatomic, copy)AFURLSessionTaskProgressBlock _Nullable downloadProgressBlock;


@property (nonatomic, copy)TFRequestCustomHeaderFieldValueBlock _Nullable customHeaderFieldValueBlock;

@property (nonatomic, copy)TFRequestCompletionBlock _Nullable completionBlock;

+ (TransfoRequest *)transfo:(TFRequestMethod)HTTPMethod;

- (NSString *)requestMethod;

- (void)invalid;

@end






@interface TransfoChainRequest : NSObject

@property (nonatomic, copy)TFRequestCompletionBlock _Nullable processorBlock;
@property (nonatomic, copy)TFGroupRequestCompletionBlock _Nullable completionBlock;

- (void)addRequest:(TransfoRequest *)request;
- (void)removeRequest:(TransfoRequest *)request;

- (void)start;

@end





@interface TransfoBatchRequest : NSObject

@property (nonatomic, copy)TFThenRequestHandlerBlock _Nullable thenHandler;
@property (nonatomic, copy)TFRequestCompletionBlock  _Nullable processorBlock;
@property (nonatomic, copy)TFGroupRequestCompletionBlock _Nullable completionBlock;

- (void)addRequest:(TransfoRequest *)request;
- (void)removeRequest:(TransfoRequest *)request;

- (void)start;

@end



@interface TransfoDependencyRequest : NSObject

@property (nonatomic, copy)TFThenRequestHandlerBlock _Nullable thenHandler;
@property (nonatomic, copy)TFRequestCompletionBlock  _Nullable processorBlock;
@property (nonatomic, copy)TFRequestCompletionBlock  _Nullable completionBlock;

- (void)addRequest:(TransfoRequest *)request;
- (void)removeRequest:(TransfoRequest *)request;

- (void)start;

@end





NS_ASSUME_NONNULL_END
