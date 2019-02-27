//
//  WXApiManager.m
//  WechatLogin
//
//  Created by zhengsheng on 2019/2/25.
//  Copyright © 2019 zs. All rights reserved.
//

#import "WXApiManager.h"

@implementation WXApiManager

+ (instancetype)shareManager{
    static dispatch_once_t onceToken;
    static WXApiManager *manager = nil;

    dispatch_once(&onceToken, ^{
        manager = [WXApiManager new];
    });
    return manager;
}

@end
