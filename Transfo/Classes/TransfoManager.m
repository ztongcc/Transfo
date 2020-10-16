//
//  TransfoManager.m
//  Transfo
//
//  Created by Jamis on 2020/9/2.
//  Copyright © 2020 Jemis. All rights reserved.
//

#import "TransfoManager.h"
#import <pthread/pthread.h>
#import "TransfoUtil.h"

#define _lock() pthread_mutex_lock(&_lock)
#define _unlock() pthread_mutex_unlock(&_lock)



@implementation ZTNetworkConfig

+ (ZTNetworkConfig *)sharedConfig {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _baseUrl = @"";
        _securityPolicy = [AFSecurityPolicy defaultPolicy];
        //是否允许CA不信任的证书通过
        _securityPolicy.allowInvalidCertificates = YES;
        //是否验证主机名
        _securityPolicy.validatesDomainName = NO;

        _debugLogEnabled = YES;
        
        _processor = [[TransfoProcessor alloc] init];
    }
    return self;
}

#pragma mark - NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>{ baseURL: %@ }", NSStringFromClass([self class]), self, self.baseUrl];
}

@end




@interface TransfoManager () {
    pthread_mutex_t _lock;
    ZTNetworkConfig *_config;
    NSFileManager * _fileManager;
}
@property (nonatomic, strong)dispatch_queue_t taskQueue;
@property (nonatomic, strong)dispatch_queue_t taskSerialQueue;

@property (nonatomic, strong)NSMutableDictionary * taskMap;


@property (nonatomic, assign)BOOL barrage;
@property (nonatomic, strong)NSMutableArray * barrageTasks;

@property (nonatomic, strong)AFHTTPSessionManager * sessionManager;
@property (nonatomic, strong)AFJSONRequestSerializer * JSONSerializer;
@property (nonatomic, strong)AFHTTPRequestSerializer * HTTPSerializer;

@end

@implementation TransfoManager
+ (TransfoManager *)manager {
    static dispatch_once_t onceToken;
    static TransfoManager * transfo;
    dispatch_once(&onceToken, ^{
        transfo = [[[self class] alloc] init];
        [transfo setup];
    });
    return transfo;
}

- (void)setup {
    
    _config = [ZTNetworkConfig sharedConfig];
    
    NSURLSessionConfiguration * configuration = _config.sessionConfiguration?_config.sessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration];
    self.sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:_config.baseUrl] sessionConfiguration:configuration];
    
    _sessionManager.securityPolicy = _config.securityPolicy;
    _sessionManager.completionQueue = dispatch_queue_create("com.transfo.task.completion.queue", DISPATCH_QUEUE_SERIAL);

    
    AFJSONResponseSerializer * responseSerializer = [AFJSONResponseSerializer serializer];
    responseSerializer.readingOptions = NSJSONReadingAllowFragments;
    responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/plain", @"text/javascript", @"text/json", @"text/html", @"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",@"application/pdf", nil];
    _sessionManager.responseSerializer = responseSerializer;


    if (@available(iOS 10, *)) {
        [_sessionManager setTaskDidFinishCollectingMetricsBlock:_config.collectingMetricsBlock];
    }
    
    
    pthread_mutex_init(&_lock, NULL);

    _taskQueue = dispatch_queue_create("com.transfo.task.invoke.queue", DISPATCH_QUEUE_CONCURRENT);
    _taskMap = [NSMutableDictionary dictionaryWithCapacity:1];
    
    _barrageTasks = [NSMutableArray arrayWithCapacity:1];
    
    
    self.logEnable = YES;
}


- (void)dataTask:(TFRequestHandlerBlock)requestHandler {
    TransfoRequest * request = [[TransfoRequest alloc] init];
    if (requestHandler) {
        requestHandler(request);
    }
    [self start:request];
}

- (void)start:(TransfoRequest *)request {
    if (self.barrage) {
        [self.barrageTasks addObject:request];
    }else {
        if (request.barrage) {
            _lock(); self.barrage = YES; _unlock();
        }
        // 发送请求
        BOOL enable = YES;
        if ([_config.processor respondsToSelector:@selector(transfo:shouldStartRequest:)]) {
            enable = [_config.processor transfo:self shouldStartRequest:request];
        }
        if (enable) {
            NSError * __autoreleasing requestSerializationError = nil;
            NSURLSessionTask * dataTask = [self dataTaskWithTransfo:request error:&requestSerializationError];
            
            if (requestSerializationError) {
                TransfoResponse * response = [self responseWithRequest:request error:requestSerializationError];
                [self requestDidFailWithResponse:response error:requestSerializationError];
                return;
            }
            
            if ([request.dataTask respondsToSelector:@selector(priority)]) {
                request.dataTask.priority = request.priority;
            }
            
            request.dataTask = dataTask;
            
            [self addRequestToRecord:request];
            [dataTask resume];
        }
    }
}

- (void)cancel:(TransfoRequest *)request {
    NSParameterAssert(request != nil);
    if (request.resumableDownloadPath && [TransfoUtil incompleteDownloadTempPathForDownloadPath:request.resumableDownloadPath] != nil) {
        NSURLSessionDownloadTask *requestTask = (NSURLSessionDownloadTask *)request.dataTask;
        [requestTask cancelByProducingResumeData:^(NSData *resumeData) {
            NSURL *localUrl = [TransfoUtil incompleteDownloadTempPathForDownloadPath:request.resumableDownloadPath];
            [resumeData writeToURL:localUrl atomically:YES];
        }];
    } else {
        [request.dataTask cancel];
    }
}

- (void)cancleAllActiveTasks {
    NSArray * tasks = self.sessionManager.tasks;
    [tasks enumerateObjectsUsingBlock:^(NSURLSessionTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj cancel];
    }];
}

- (void)removeAllBlockedRequests {
    [self.barrageTasks enumerateObjectsUsingBlock:^(TransfoRequest *_Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj invalid];
    }];
    [self.barrageTasks removeAllObjects];
}

- (NSArray *)allRequests {
    return [self.taskMap allValues];
}

- (void)restartBlockedRequests {
    _lock(); self.barrage = NO; _unlock();
    [self.barrageTasks enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self start:obj];
    }];
    [self removeAllBlockedRequests];
}

- (void)addRequestToRecord:(TransfoRequest *)request {
    _lock();
    _taskMap[@(request.dataTask.taskIdentifier)] = request;
    _unlock();
}

- (void)removeRequestFromRecord:(TransfoRequest *)request {
    _lock();
    [_taskMap removeObjectForKey:@(request.dataTask.taskIdentifier)];
    _unlock();
}

- (NSURLSessionTask *)dataTaskWithTransfo:(TransfoRequest *)transfo
                                    error:(NSError * _Nullable __autoreleasing *)error {
    AFHTTPRequestSerializer * serializer = [_config.processor transfo:self requestSerializer:transfo];
    NSString * URLString = transfo.api;
    if ([_config.processor respondsToSelector:@selector(transfo:absoluteURL:)]) {
        URLString = [_config.processor transfo:self absoluteURL:transfo];
    }
    URLString = [[NSURL URLWithString:URLString relativeToURL:self.sessionManager.baseURL] absoluteString];

    if (transfo.resumableDownloadPath) {
        return [self downloadTaskWithRequest:transfo requestSerializer:serializer URLString:URLString error:error];
    }else {
        return [self dataTaskWithRequest:transfo requestSerializer:serializer URLString:URLString error:error];
    }
}


- (NSURLSessionDataTask *)dataTaskWithRequest:(TransfoRequest *)transfo
                               requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                       URLString:(NSString *)URLString
                                           error:(NSError * _Nullable __autoreleasing *)error {
    NSURLRequest *request = nil;
    if (transfo.constructingBlock) {
        request = [requestSerializer multipartFormRequestWithMethod:transfo.requestMethod URLString:URLString parameters:transfo.bodyParameter constructingBodyWithBlock:transfo.constructingBlock error:error];
    } else {
        request = [requestSerializer requestWithMethod:transfo.requestMethod URLString:URLString parameters:transfo.bodyParameter error:error];
    }
    __block NSURLSessionDataTask *dataTask = nil;
    typeof(self) weakself = self;
    dataTask = [self.sessionManager dataTaskWithRequest:request uploadProgress:transfo.uploadProgressBlock downloadProgress:transfo.downloadProgressBlock  completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable responseError) {
        [weakself onCompletionResult:dataTask response:response responseData:responseObject error:responseError];
    }];
    return dataTask;
}


- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(TransfoRequest *)transfo
                                    requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                            URLString:(NSString *)URLString
                                                error:(NSError * _Nullable __autoreleasing *)error {

    // add parameters to URL;
    NSMutableURLRequest *urlRequest = [requestSerializer requestWithMethod:transfo.requestMethod URLString:URLString parameters:transfo.bodyParameter error:error];

    NSString * downloadPath = transfo.resumableDownloadPath;

    BOOL isDirectory;
    if (![[self fileManager] fileExistsAtPath:downloadPath isDirectory:&isDirectory]) {
        isDirectory = NO;
    }
    
    // If targetPath is a directory, use the file name we got from the urlRequest.
    // Make sure downloadTargetPath is always a file, not directory.
    NSString *downloadTargetPath;
    if (isDirectory) {
        NSString *fileName = [urlRequest.URL lastPathComponent];
        downloadTargetPath = [NSString pathWithComponents:@[downloadPath, fileName]];
    } else {
        downloadTargetPath = downloadPath;
    }

    // AFN use `moveItemAtURL` to move downloaded file to target path,
    // this method aborts the move attempt if a file already exist at the path.
    // So we remove the exist file before we start the download task.
    // https://github.com/AFNetworking/AFNetworking/issues/3775
    if ([[self fileManager] fileExistsAtPath:downloadTargetPath]) {
        [[self fileManager] removeItemAtPath:downloadTargetPath error:nil];
    }

    BOOL resumeSucceeded = NO;
    __block NSURLSessionDownloadTask *downloadTask = nil;
    NSURL *localUrl = [TransfoUtil incompleteDownloadTempPathForDownloadPath:downloadPath];
    if (localUrl != nil) {
        BOOL resumeDataFileExists = [[self fileManager] fileExistsAtPath:localUrl.path];
        NSData *data = [NSData dataWithContentsOfURL:localUrl];
        BOOL resumeDataIsValid = [TransfoUtil validateResumeData:data];

        BOOL canBeResumed = resumeDataFileExists && resumeDataIsValid;
        // Try to resume with resumeData.
        // Even though we try to validate the resumeData, this may still fail and raise excecption.
        if (canBeResumed) {
            @try {
                downloadTask = [_sessionManager downloadTaskWithResumeData:data progress:transfo.downloadProgressBlock destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                    return [NSURL fileURLWithPath:downloadTargetPath isDirectory:NO];
                } completionHandler:
                                ^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                    [self onCompletionResult:downloadTask response:response responseData:filePath error:error];
                }];
                resumeSucceeded = YES;
            } @catch (NSException *exception) {
                NSLog(@"Resume download failed, reason = %@", exception.reason);
                resumeSucceeded = NO;
            }
        }
    }
    if (!resumeSucceeded) {
        downloadTask = [_sessionManager downloadTaskWithRequest:urlRequest progress:transfo.downloadProgressBlock destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            return [NSURL fileURLWithPath:downloadTargetPath isDirectory:NO];
        } completionHandler:
                        ^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            [self onCompletionResult:downloadTask response:response responseData:filePath error:error];
        }];
    }
    return downloadTask;
}

- (void)onCompletionResult:(NSURLSessionTask *)task response:(NSURLResponse *)response responseData:(id)responseObject error:(NSError *)error {
    _lock();
    TransfoRequest * request = self.taskMap[@(task.taskIdentifier)];
    _unlock();
    
    if (!request) return;
    
    TransfoResponse * mResponse = [self responseWithResponseData:responseObject response:response error:error];
    mResponse.request = request;
    [self _log:request response:mResponse];
    
    
    BOOL invalid = NO;
    if (request.ignore || mResponse.statusCode == NSURLErrorCancelled) {
        invalid = YES; [request invalid];
    }
    

    if (!invalid) {
        if (_config.processor) {
            [_config.processor transfo:self response:mResponse error:error];
        }
        
        if (request.completionBlock && mResponse) {
            dispatch_async(dispatch_get_main_queue(), ^{
                request.completionBlock(mResponse);
            });
        }
    }
    
    dispatch_async(_taskQueue, ^{
        [self removeRequestFromRecord:request];
    });

    if (request.barrage) {
        [self restartBlockedRequests];
    }
}


- (void)requestDidFailWithResponse:(TransfoResponse *)response error:(NSError *)error {
    response.error = error;
    // Save incomplete download data.
    NSData *incompleteDownloadData = error.userInfo[NSURLSessionDownloadTaskResumeData];
    NSURL * resumeLocalUrl = nil;
    if (response.request.resumableDownloadPath) {
        resumeLocalUrl = [TransfoUtil incompleteDownloadTempPathForDownloadPath:response.request.resumableDownloadPath];
    }
    if (incompleteDownloadData && resumeLocalUrl != nil) {
        [incompleteDownloadData writeToURL:resumeLocalUrl atomically:YES];
    }

    // Load response from file and clean up if download task failed.
    if ([response.responseObject isKindOfClass:[NSURL class]]) {
        NSURL *url = response.responseObject;
        if (url.isFileURL && [[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
            [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        }
    }
}

- (NSFileManager *)fileManager {
    if (!_fileManager) {
        _fileManager = [NSFileManager defaultManager];
    }
    return _fileManager;
}

- (TransfoResponse *)responseWithResponseData:(id)responseObject response:(NSURLResponse *)response error:(NSError *)error {
    TransfoResponse * res = [[TransfoResponse alloc] init];
    res.HTTPHeaderFields = ((NSHTTPURLResponse *)response).allHeaderFields;
    res.statusCode = ((NSHTTPURLResponse *)response).statusCode;
    res.responseObject = responseObject;
    res.error = error;
    res.status = error?NO:YES;
    return res;
}

- (TransfoResponse *)responseWithRequest:(TransfoRequest *)request error:(NSError *)error {
    TransfoResponse * res = [[TransfoResponse alloc] init];
    res.request = request;
    res.error = error;
    res.status = error?NO:YES;
    return res;
}


- (void)_log:(TransfoRequest *)request response:(TransfoResponse *)response {
    if (_config.debugLogEnabled) {
        NSLog(@"\n\n--------------- start %@ request -------------------\n --> api : %@\n --> header : \n%@ \n --> pathParameter: \n%@ \n --> queryParameter: \n%@ \n --> bodyParameter: \n%@\n --> responseObj: \n%@ \n --> error: \n%@ \n --> error.userInfo: \n%@\n", request.requestMethod, request.api, request.dataTask.currentRequest.allHTTPHeaderFields,request.pathParameter, request.queryParameter, request.bodyParameter,response.responseObject,response.error, response.errorInfo);
    }
}

@end



@implementation TransfoManager (HTTP)

- (TransfoRequest *)HTTP:(TFRequestMethod)HTTPMethod
                 process:(TFRequestHandlerBlock)requestHandler
             complection:(TFRequestCompletionBlock)complecteHandler {
    TransfoRequest * request = [TransfoRequest transfo:HTTPMethod];
    request.completionBlock = complecteHandler;
    if (requestHandler) {
        requestHandler(request);
    }
    [self start:request];
    return request;
}

- (TransfoRequest *)GET:(TFRequestHandlerBlock)requestHandler
            complection:(TFRequestCompletionBlock)handler {
    return [self HTTP:TFGET process:requestHandler complection:handler];
}

- (TransfoRequest *)POST:(TFRequestHandlerBlock)requestHandler
             complection:(TFRequestCompletionBlock)handler {
    return [self HTTP:TFPOST process:requestHandler complection:handler];
}

- (TransfoRequest *)PUT:(TFRequestHandlerBlock)requestHandler
            complection:(TFRequestCompletionBlock)handler {
    return [self HTTP:TFPUT process:requestHandler complection:handler];
}

- (TransfoRequest *)DELETE:(TFRequestHandlerBlock)requestHandler
               complection:(TFRequestCompletionBlock)handler {
    return [self HTTP:TFDELETE process:requestHandler complection:handler];
}

- (TransfoRequest *)PATCH:(TFRequestHandlerBlock)requestHandler
              complection:(TFRequestCompletionBlock)handler {
    return [self HTTP:TFPATCH process:requestHandler complection:handler];
}

- (TransfoRequest *)HEAD:(void (^)(TransfoRequest * _Nonnull))requestHandler
             complection:(void (^)(TransfoResponse * _Nonnull))handler {
    return [self HTTP:TFHEAD process:requestHandler complection:handler];
}


- (void)batch:(void (^)(TransfoBatchRequest * rq))requestHandler
    processor:(TFRequestCompletionBlock)processor
  complection:(TFGroupRequestCompletionBlock)complectionHandler {
    TransfoBatchRequest * request = [[TransfoBatchRequest alloc] init];
    request.processorBlock = processor;
    request.completionBlock = complectionHandler;
    if (requestHandler) {
        requestHandler(request);
    }
    [request start];
}


- (void)chain:(void (^)(TransfoChainRequest * rq))requestHandler
    processor:(TFRequestCompletionBlock)processor
  complection:(TFGroupRequestCompletionBlock)complectionHandler {
    TransfoChainRequest * request = [[TransfoChainRequest alloc] init];
    request.processorBlock = processor;
    request.completionBlock = complectionHandler;
    if (requestHandler) {
        requestHandler(request);
    }
    [request start];
}

- (void)dependency:(void (^)(TransfoDependencyRequest * brq))requestHandler
         processor:(TFRequestCompletionBlock)processor
              then:(TFThenRequestHandlerBlock)thenHandler
       complection:(TFRequestCompletionBlock)complectionHandler {
    TransfoDependencyRequest * request = [[TransfoDependencyRequest alloc] init];
    request.processorBlock = processor;
    request.completionBlock = complectionHandler;
    request.thenHandler = thenHandler;
    if (requestHandler) {
        requestHandler(request);
    }
    [request start];
}

@end
