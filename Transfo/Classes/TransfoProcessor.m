//
//  TransfoProcessor.m
//  Transfo
//
//  Created by Jamis on 2020/9/16.
//  Copyright © 2020 Jemis. All rights reserved.
//

#import "TransfoProcessor.h"
#import "TransfoManager.h"
#import "TransfoResponse.h"
#import "TransfoRequest.h"
#import "AFURLResponseSerialization.h"
#import "AFURLRequestSerialization.h"

@implementation TransfoProcessor

- (AFHTTPRequestSerializer *)transfo:(TransfoManager *)manager requestSerializer:(TransfoRequest *)request {
    AFHTTPRequestSerializer * serializer;
    if (request.requestSerializerType == TFRequestSerializerTypeHTTP) {
        serializer = [AFHTTPRequestSerializer serializer];
    }else {
        serializer = [AFJSONRequestSerializer serializerWithWritingOptions:NSJSONWritingPrettyPrinted];
    }
    
    // If api needs to add custom value to HTTPHeaderField
    if (request.customHeaderFieldValueBlock != nil) {
        NSDictionary<NSString *, NSString *> *headerFieldValueDictionary = request.customHeaderFieldValueBlock();
        for (NSString *httpHeaderField in headerFieldValueDictionary.allKeys) {
            NSString *value = headerFieldValueDictionary[httpHeaderField];
            [serializer setValue:value forHTTPHeaderField:httpHeaderField];
        }
    }
    
    
    if (request.requireAuthorization) {
        NSUserDefaults * userDefault = [NSUserDefaults standardUserDefaults];
        
        NSString * token = [userDefault objectForKey:@"access_token"];
        if (token.length == 0 || [request.api isEqualToString:@"esenuaa/oauth/token"]) {
            // d2ViX2FwcDo=
            token = @"Basic bW9iaWxlX25hdGl2ZV9hcHA6NjF3NFUyenJjQjg4";
        } else {
            token = [NSString stringWithFormat:@"Bearer %@", token];
        }
        
        [serializer setValue:token forHTTPHeaderField:@"Authorization"];
    }
    [serializer setValue:@"IOS" forHTTPHeaderField:@"Channel"];

    return serializer;
}


- (NSString *)transfo:(TransfoManager *)manager absoluteURL:(TransfoRequest *)request {
    if (!request.api) {
        return @"";
    }
    __block NSMutableString * url = [[NSMutableString alloc] initWithString:request.api];
    if (request.pathParameter) {
        id param = request.pathParameter;
        if ([param isKindOfClass:[NSDictionary class]]) {
            [(NSDictionary *)param enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                if ([url containsString:key]) {
                    NSRange range = [url rangeOfString:key];
                    [url replaceCharactersInRange:range withString:obj];
                }
            }];
        }else if ([param isKindOfClass:[NSString class]]) {
            if (![url hasSuffix:@"/"]) {
                [url appendString:@"/"];
            }
            [url appendString:[(NSString *)param stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]]];
        }
    }
    
    if (request.queryParameter) {
        if ([request.queryParameter isKindOfClass:[NSDictionary class]]) {
            NSURL * tmp = [NSURL URLWithString:url];
            NSString * query = AFQueryStringFromParameters(request.queryParameter);
            [url appendFormat:tmp.query? @"&%@" : @"?%@", query];
        }else if ([request.queryParameter isKindOfClass:[NSString class]]) {
            [url appendString:[(NSString *)request.queryParameter stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]]];
        }
    }
    return url;
}

- (void)transfo:(TransfoManager *)manager response:(TransfoResponse *)response error:(NSError *)error {
    if (error) {
        if (error.domain == NSCocoaErrorDomain) {
            response.errorMsg = [self errorMessageWithCode:error.code];
        }else if (error.domain == AFURLResponseSerializationErrorDomain) {
            if (error.userInfo) {
                NSData * data = (NSData *)error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
                if (data) {
                    response.errorInfo = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
                }
                NSHTTPURLResponse * response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
                if (response.statusCode == 401) {
                    [[TransfoManager manager] removeAllBlockedRequests];
                    [[TransfoManager manager] cancleAllActiveTasks];
                }
            }
        }
    }
}

- (BOOL)transfo:(TransfoManager *)manager shouldStartRequest:(TransfoRequest *)request {
    return YES;
}


- (void)refreshToken {
    
    NSUserDefaults * userDefault = [NSUserDefaults standardUserDefaults];
    NSString * refreshToken = [userDefault objectForKey:@"refresh_token"];
    
    if (refreshToken) {
        NSDictionary *paramDic = @{@"refresh_token":refreshToken,
                                   @"grant_type":@"refresh_token"};
        [[TransfoManager manager] POST:^(TransfoRequest * _Nonnull rq) {
            rq.api = @"esenuaa/oauth/token";
            rq.bodyParameter = paramDic;
            rq.requireAuthorization = NO;
            rq.barrage = YES;
            rq.queryParameter = @{@"force":@"true"};
            rq.requestSerializerType = TFRequestSerializerTypeHTTP;
        } complection:^(TransfoResponse * _Nonnull rs) {
            if (rs.status) {
                NSUserDefaults * userDefault = [NSUserDefaults standardUserDefaults];
                [userDefault setObject:rs.responseObject[@"access_token"] forKey:@"access_token"];
                [userDefault setObject:rs.responseObject[@"refresh_token"] forKey:@"refresh_token"];
                [userDefault synchronize];
            }else {
                
            }
        }];
    }
}

- (NSString *)errorMessageWithCode:(NSInteger)code {
    if (code == NSURLErrorCancelled) {
        return @"";
    }
    if (code == NSURLErrorUnknown || code == NSURLErrorBadURL) {
        return @"无效的URL地址";
    }else if (code == NSURLErrorTimedOut) {
        return @"网络不给力，请稍后再试";
    }else if (code == NSURLErrorUnsupportedURL) {
        return @"不支持的URL地址";
    }else if (code == NSURLErrorCannotFindHost) {
        return @"找不到服务器";
    }else if (code == NSURLErrorCannotConnectToHost) {
        return @"连接不上服务器";
    }else if (code == NSURLErrorNetworkConnectionLost) {
        return @"网络连接异常";
    }else if (code == NSURLErrorNotConnectedToInternet) {
        return @"无网络连接";
    }else {
        return @"服务器或接口异常";
    }
}

@end
