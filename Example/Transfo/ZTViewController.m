//
//  ZTViewController.m
//  Transfo
//
//  Created by ztongcc on 10/16/2020.
//  Copyright (c) 2020 ztongcc. All rights reserved.
//

#import "ZTViewController.h"
#import <TransfoManager.h>

@interface ZTViewController ()

@end

@implementation ZTViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setup];
}

- (void)setup {
    [ZTNetworkConfig sharedConfig].baseUrl = @"https://xxxx.xxxx.cn/";
    [ZTNetworkConfig sharedConfig].debugLogEnabled = NO;
}

- (IBAction)login:(id)sender {
    
    NSDictionary *paramDic = @{@"username":@"xxxxxx",
                               @"password":@"xxxxx",
                               @"grant_type":@"password",
                               @"scope":@"app"};

    [[TransfoManager manager] POST:^(TransfoRequest * _Nonnull rq) {
        rq.api = @"esenuaa/oauth/token";
        rq.bodyParameter = paramDic;
        rq.requestSerializerType = TFRequestSerializerTypeHTTP;
    } complection:^(TransfoResponse * _Nonnull rs) {
        if (rs.status) {
            NSLog(@"%@", rs.responseObject);
            
        }
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
