//
//  TransfoManager.h
//  Transfo
//
//  Created by Jamis on 2020/9/2.
//  Copyright © 2020 Jemis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>
#import "TransfoRequest.h"
#import "TransfoResponse.h"
#import "TransfoProcessor.h"

NS_ASSUME_NONNULL_BEGIN

#if AF_CAN_INCLUDE_SESSION_TASK_METRICS
typedef void (^AFURLSessionTaskDidFinishCollectingMetricsBlock)(NSURLSession *session, NSURLSessionTask *task, NSURLSessionTaskMetrics * metrics) API_AVAILABLE(ios(10), macosx(10.12), watchos(3), tvos(10));
#endif




@interface ZTNetworkConfig : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

///  Return a shared config object.
+ (ZTNetworkConfig *)sharedConfig;

///  Request base URL, such as "http://www.xxxxx.com". Default is empty string.
@property (nonatomic, strong) NSString *baseUrl;

///  Security policy will be used by AFNetworking. See also `AFSecurityPolicy`.
@property (nonatomic, strong) AFSecurityPolicy *securityPolicy;
///  Whether to log debug info. Default is NO;
@property (nonatomic) BOOL debugLogEnabled;
///  SessionConfiguration will be used to initialize AFHTTPSessionManager. Default is nil.
@property (nonatomic, strong) NSURLSessionConfiguration* sessionConfiguration;
///  NSURLSessionTaskMetrics
@property (nonatomic, strong) AFURLSessionTaskDidFinishCollectingMetricsBlock collectingMetricsBlock API_AVAILABLE(ios(10), macosx(10.12), watchos(3), tvos(10));

@property (nonatomic, strong)id <TransfoResponseProcessor> processor;

@end



@interface TransfoManager : NSObject


@property (nonatomic, readonly)AFHTTPSessionManager * sessionManager;

@property (nonatomic, readonly)NSArray * allRequests;

// 是否打印网络请求  默认为 YES
@property (nonatomic, assign)BOOL logEnable;

+ (TransfoManager *)manager;

- (void)dataTask:(TFRequestHandlerBlock)request;

- (void)start:(TransfoRequest *)request;

- (void)cancel:(TransfoRequest *)request;


// 取消所有请求
- (void)cancleAllActiveTasks;
- (void)removeAllBlockedRequests;

@end




@interface TransfoManager (HTTP)

- (TransfoRequest *)GET:(TFRequestHandlerBlock)requestHandler
            complection:(TFRequestCompletionBlock)complectionHandler;

- (TransfoRequest *)POST:(TFRequestHandlerBlock)requestHandler
             complection:(TFRequestCompletionBlock)complectionHandler;

- (TransfoRequest *)PUT:(TFRequestHandlerBlock)requestHandler
            complection:(TFRequestCompletionBlock)complectionHandler;

- (TransfoRequest *)DELETE:(TFRequestHandlerBlock)requestHandler
               complection:(TFRequestCompletionBlock)complectionHandler;

- (TransfoRequest *)HEAD:(TFRequestHandlerBlock)requestHandler
             complection:(TFRequestCompletionBlock)complectionHandler;

- (TransfoRequest *)PATCH:(TFRequestHandlerBlock)requestHandler
              complection:(TFRequestCompletionBlock)complectionHandler;


- (void)batch:(void (^)(TransfoBatchRequest * brq))requestHandler
    processor:(TFRequestCompletionBlock)processor
  complection:(TFGroupRequestCompletionBlock)complectionHandler;

- (void)chain:(void (^)(TransfoChainRequest * crq))requestHandler
    processor:(TFRequestCompletionBlock)processor
  complection:(TFGroupRequestCompletionBlock)complectionHandler;

- (void)dependency:(void (^)(TransfoDependencyRequest * brq))requestHandler
         processor:(TFRequestCompletionBlock)processor
              then:(TFThenRequestHandlerBlock)thenHandler
       complection:(TFRequestCompletionBlock)complectionHandler;

@end

NS_ASSUME_NONNULL_END
