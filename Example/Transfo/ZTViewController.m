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
    [TFNetworkConfig sharedConfig].baseUrl = @"https://gateway.nextxx.cn:9091/";
    [TFNetworkConfig sharedConfig].debugLogEnabled = NO;
}

- (IBAction)login:(id)sender {
    
    NSDictionary *paramDic = @{@"username":@"13524164536",
                               @"password":@"123321",
                               @"grant_type":@"password",
                               @"scope":@"app"};

    [[TransfoManager manager] POST:^(TransfoRequest * _Nonnull rq) {
        rq.api = @"esenuaa/oauth/token";
        rq.bodyParameter = paramDic;
        rq.requestSerializerType = TFRequestSerializerTypeHTTP;
    } complection:^(TransfoResponse * _Nonnull rs) {
        if (rs.status) {
            NSLog(@"%@", rs.responseObject);
            NSUserDefaults * userDefault = [NSUserDefaults standardUserDefaults];
            [userDefault setObject:rs.responseObject[@"access_token"] forKey:@"access_token"];
            [userDefault setObject:rs.responseObject[@"refresh_token"] forKey:@"refresh_token"];

            [userDefault synchronize];
        }
    }];
}
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
