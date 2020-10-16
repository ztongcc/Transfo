//
//  TransfoRequest.m
//  Transfo
//
//  Created by Jamis on 2020/9/2.
//  Copyright © 2020 Jemis. All rights reserved.
//

#import "TransfoRequest.h"
#import <objc/runtime.h>
#import "TransfoManager.h"

@interface TransfoRequest ()

@property (nonatomic, strong)TransfoBatchRequest * batch;
@property (nonatomic, strong)TransfoChainRequest * chain;
@property (nonatomic, strong)TransfoDependencyRequest * dependency;

@end


@implementation TransfoRequest

+ (TransfoRequest *)transfo:(TFRequestMethod)HTTPMethod {
    TransfoRequest * req = [[TransfoRequest alloc] init];
    req.HTTPMethod = HTTPMethod;
    return req;
}


- (instancetype)init {
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    _requireAuthorization = YES;
    _priority = NSURLSessionTaskPriorityDefault;
}

- (NSString *)requestMethod {
    NSString *  method = @"GET";
    switch (_HTTPMethod) {
        case TFGET:
            method = @"GET";
            break;
        case TFPOST:
            method = @"POST";
            break;
        case TFPUT:
            method = @"PUT";
            break;
        case TFDELETE:
            method = @"DELETE";
            break;
        case TFPATCH:
            method = @"PATCH";
            break;
        case TFHEAD:
            method = @"HEAD";
            break;
        default:
            break;
    }
    return method;
}

- (void)invalid {
    if (self.batch) {
        self.batch = nil;
        self.completionBlock = nil;
    }
    
    if (self.chain) {
        [self.chain start];
        self.chain = nil;
        self.completionBlock = nil;
    }
}

// 重写debugDescription, 而不是description
- (NSString *)debugDescription {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    uint count;
    objc_property_t *properties = class_copyPropertyList([self class], &count);
    for (int i = 0; i<count; i++) {
        objc_property_t property = properties[i];
        NSString *name = @(property_getName(property));
        id value = [self valueForKey:name]?[self valueForKey:name]:@"nil";
        [dictionary setObject:value forKey:name];
    }
    free(properties);
    return [NSString stringWithFormat:@"<%@: %p> -- %@",[self class],self,dictionary];
}

- (void)dealloc {
    
    NSLog(@"%s",__func__);
}

@end



@interface TransfoChainRequest ()

@property (nonatomic, strong)NSMutableArray * requests;
@property (nonatomic, strong)NSMutableArray * responseGroup;

@end

@implementation TransfoChainRequest
- (void)start {
    if (self.requests.count == 0) return;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        TransfoRequest * req = [self.requests firstObject];
        __weak typeof(self) weakself = self;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        req.completionBlock = ^(TransfoResponse * _Nonnull rs) {
            if (weakself.processorBlock) {
                weakself.processorBlock(rs);
            }
            rs.request.chain = nil;
            [weakself.responseGroup addObject:rs];
            dispatch_semaphore_signal(semaphore);
        };
        req.chain = self;
        [[TransfoManager manager] start:req];
        [self.requests removeObject:req];
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        [self onRunloop];
    });
}

- (void)onRunloop {
    if (self.requests.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completionBlock) {
                self.completionBlock(self.responseGroup);
            }
        });
    }else {
        [self start];
    }
}

- (void)addRequest:(TransfoRequest *)request {
    [self.requests addObject:request];
}

- (void)removeRequest:(TransfoRequest *)request {
    [self.requests removeObject:request];
}

- (NSMutableArray *)requests {
    if (!_requests) {
        _requests = [NSMutableArray arrayWithCapacity:1];
    }
    return _requests;
}
- (NSMutableArray *)responseGroup {
    if (!_responseGroup) {
        _responseGroup = [NSMutableArray arrayWithCapacity:1];
    }
    return _responseGroup;
}
- (void)dealloc {
    NSLog(@"%s",__func__);
}
@end




@interface TransfoBatchRequest ()

@property (nonatomic, strong)NSMutableArray * requests;
@property (nonatomic, strong)NSMutableArray * responseGroup;

@end


@implementation TransfoBatchRequest

- (void)start {
    if (self.requests.count == 0) return;
    
    dispatch_group_t group = dispatch_group_create();
    
    for (TransfoRequest * req in self.requests) {
        __weak typeof(self) weakself = self;
        dispatch_group_enter(group);
        req.completionBlock = ^(TransfoResponse * _Nonnull rs) {
            if (weakself.processorBlock) {
                weakself.processorBlock(rs);
            }
            [weakself.responseGroup addObject:rs];
            rs.request.batch = nil;
            dispatch_group_leave(group);
        };
        req.batch = self;
        [[TransfoManager manager] start:req];
    }
    [self.requests removeAllObjects];
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (self.completionBlock) {
            self.completionBlock(self.responseGroup);
        }
    });
    
}

- (void)addRequest:(TransfoRequest *)request {
    [self.requests addObject:request];
}

- (void)removeRequest:(TransfoRequest *)request {
    [self.requests removeObject:request];
}

- (NSMutableArray *)requests {
    if (!_requests) {
        _requests = [NSMutableArray arrayWithCapacity:1];
    }
    return _requests;
}
- (NSMutableArray *)responseGroup {
    if (!_responseGroup) {
        _responseGroup = [NSMutableArray arrayWithCapacity:1];
    }
    return _responseGroup;
}

- (void)dealloc {
    NSLog(@"%s",__func__);
}
@end






@interface TransfoDependencyRequest ()

@property (nonatomic, strong)NSMutableArray * requests;
@property (nonatomic, strong)NSMutableArray * responseGroup;

@end


@implementation TransfoDependencyRequest

- (void)start {
    if (self.requests.count == 0) return;
    
    dispatch_group_t group = dispatch_group_create();
    
    for (TransfoRequest * req in self.requests) {
        __weak typeof(self) weakself = self;
        dispatch_group_enter(group);
        req.completionBlock = ^(TransfoResponse * _Nonnull rs) {
            if (weakself.processorBlock) {
                weakself.processorBlock(rs);
            }
            [weakself.responseGroup addObject:rs];
            rs.request.dependency = nil;
            dispatch_group_leave(group);
        };
        req.dependency = self;
        [[TransfoManager manager] start:req];
    }
    [self.requests removeAllObjects];
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (self.thenHandler) {
            TransfoRequest * request = [TransfoRequest transfo:TFGET];
            request.completionBlock = self.completionBlock;
            self.thenHandler(self.responseGroup, request);
            [[TransfoManager manager] start:request];
        }
    });
}

- (void)addRequest:(TransfoRequest *)request {
    [self.requests addObject:request];
}

- (void)removeRequest:(TransfoRequest *)request {
    [self.requests removeObject:request];
}

- (NSMutableArray *)requests {
    if (!_requests) {
        _requests = [NSMutableArray arrayWithCapacity:1];
    }
    return _requests;
}
- (NSMutableArray *)responseGroup {
    if (!_responseGroup) {
        _responseGroup = [NSMutableArray arrayWithCapacity:1];
    }
    return _responseGroup;
}

- (void)dealloc {
    NSLog(@"%s",__func__);
}
@end
