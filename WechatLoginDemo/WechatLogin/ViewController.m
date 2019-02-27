//
//  ViewController.m
//  WechatLogin
//
//  Created by zhengsheng on 2019/2/25.
//  Copyright © 2019 zs. All rights reserved.
//

#import "ViewController.h"
#import "WXApi.h"
#import <AFNetworking/AFNetworking.h>


@interface ViewController ()<WXApiDelegate>
{
    NSString *_code;//用户换取access_token的code，仅在ErrCode为0时有效
/*    NSString *_accessToken;//接口调用凭证
    NSString *_refreshToken;//用户刷新access_token
    NSString *_openid;//授权用户唯一标识
    NSString *_scope;//用户授权的作用域，使用逗号（,）分隔
    NSString *_unionid; //当且仅当该移动应用已获得该用户的userinfo授权时，才会出现该字段*/
}

@property (weak, nonatomic) IBOutlet UILabel *nicknameLabel;
@property (weak, nonatomic) IBOutlet UILabel *sexLabel;
@property (weak, nonatomic) IBOutlet UILabel *addressLabel;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(wxLogin:) name:@"wxLogin" object:nil];
    
    //先判断之前是否登录过
    [self authAccessToken];
}
- (IBAction)login:(UIButton *)sender {
    
    
    [self login];
}


- (void)login{
    //判断微信是否安装
    if([WXApi isWXAppInstalled]){
        SendAuthReq *req = [[SendAuthReq alloc] init];
        req.scope = @"snsapi_userinfo";
        req.state = @"App";
        [WXApi sendAuthReq:req viewController:self delegate:self];
    }else{
        [self setupAlertController];
    }
}

- (void)setupAlertController{
    UIAlertController *vc = [UIAlertController alertControllerWithTitle:@"温馨提示" message:@"请先安装微信客户端" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *actionConfim = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    [vc addAction:actionConfim];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)wxLogin:(NSNotification*)noti{
    //获取到code
    SendAuthResp *resp = noti.object;
    NSLog(@"%@",resp.code);
    _code = resp.code;
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    NSString *url = [NSString stringWithFormat:@"https://api.weixin.qq.com/sns/oauth2/access_token?appid=%@&secret=%@&code=%@&grant_type=%@",appId,appSecret,_code,@"authorization_code"];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:@"text/html; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    
    NSMutableSet *mgrSet = [NSMutableSet set];
    mgrSet.set = manager.responseSerializer.acceptableContentTypes;
    [mgrSet addObject:@"text/html"];
    //因为微信返回的参数是text/plain 必须加上 会进入fail方法
    [mgrSet addObject:@"text/plain"];
    [mgrSet addObject:@"application/json"];
    manager.responseSerializer.acceptableContentTypes = mgrSet;
    
    [manager GET:url parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"success");
        NSDictionary *resp = (NSDictionary*)responseObject;
        NSString *openid = resp[@"openid"];
        NSString *unionid = resp[@"unionid"];
        NSString *accessToken = resp[@"access_token"];
        NSString *refreshToken = resp[@"refresh_token"];
        if(accessToken && ![accessToken isEqualToString:@""] && openid && ![openid isEqualToString:@""]){
            [[NSUserDefaults standardUserDefaults] setObject:openid forKey:WX_OPEN_ID];
            [[NSUserDefaults standardUserDefaults] setObject:accessToken forKey:WX_ACCESS_TOKEN];
            [[NSUserDefaults standardUserDefaults] setObject:refreshToken forKey:WX_REFRESH_TOKEN];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        [self getUserInfo];
     
  
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
    }];
    
}

- (void)authAccessToken{
    //验证accessToken是否是成功
    NSString *accessToken = [[NSUserDefaults standardUserDefaults] objectForKey:WX_ACCESS_TOKEN];
    NSString *openid = [[NSUserDefaults standardUserDefaults] objectForKey:WX_OPEN_ID];
    if(!accessToken || [accessToken isEqualToString:@""] || !openid || [openid isEqualToString:@""]){
        //如果没登陆过，则登陆
        [self login];
    }else{
        //否则验证access token 是否还有效
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        NSString *url = [NSString stringWithFormat:@"https://api.weixin.qq.com/sns/auth?access_token=%@&openid=%@",accessToken,openid];
        
        NSMutableSet *mgrSet = [NSMutableSet set];
        mgrSet.set = manager.responseSerializer.acceptableContentTypes;
        [mgrSet addObject:@"text/html"];
        //因为微信返回的参数是text/plain 必须加上 会进入fail方法
        [mgrSet addObject:@"text/plain"];
        [mgrSet addObject:@"application/json"];
        manager.responseSerializer.acceptableContentTypes = mgrSet;
        
        [manager GET:url parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
            
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            NSLog(@"success");
            NSDictionary *resp = (NSDictionary*)responseObject;
            if([resp[@"errcode"] intValue] == 0){
                //有效则直接获取信息
                [self getUserInfo];
            }else{
                //否则使用refreshtoken来刷新accesstoken
                [self refreshAccessToken];
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSLog(@"fail");
            NSLog(@"%@",task.response);
        }];
    }

    
}

- (IBAction)refreshAccessToken:(UIButton *)sender {
    
    [self refreshAccessToken];
    
}

- (void)refreshAccessToken{
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    NSString *url = [NSString stringWithFormat:@"https://api.weixin.qq.com/sns/oauth2/refresh_token?appid=%@&refresh_token=%@&grant_type=%@",[[NSUserDefaults standardUserDefaults] objectForKey:WX_OPEN_ID],[[NSUserDefaults standardUserDefaults] objectForKey:WX_REFRESH_TOKEN],@"REFRESH_TOKEN"];
    
    NSMutableSet *mgrSet = [NSMutableSet set];
    mgrSet.set = manager.responseSerializer.acceptableContentTypes;
    [mgrSet addObject:@"text/html"];
    //因为微信返回的参数是text/plain 必须加上 会进入fail方法
    [mgrSet addObject:@"text/plain"];
    [mgrSet addObject:@"application/json"];
    manager.responseSerializer.acceptableContentTypes = mgrSet;
    
    [manager GET:url parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"success");
        NSDictionary *resp = (NSDictionary*)responseObject;
        NSString *openid = resp[@"openid"];
        NSString *accessToken = resp[@"access_token"];
        NSString *refreshToken = resp[@"refresh_token"];
        if(refreshToken){
            if(accessToken && ![accessToken isEqualToString:@""] && openid && ![openid isEqualToString:@""]){
                [[NSUserDefaults standardUserDefaults] setObject:openid forKey:WX_OPEN_ID];
                [[NSUserDefaults standardUserDefaults] setObject:accessToken forKey:WX_ACCESS_TOKEN];
                [[NSUserDefaults standardUserDefaults] setObject:refreshToken forKey:WX_REFRESH_TOKEN];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }else{
            //如果refreshToken为空，说明refreshToken也过期了，需要重新登陆
            [self login];
        }

    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"fail");
        NSLog(@"%@",task.response);
    }];
}

- (IBAction)getUserInfo:(UIButton *)sender {
    [self getUserInfo];
}

- (void)getUserInfo{
    //获取个人信息
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    NSString *url = [NSString stringWithFormat:@"https://api.weixin.qq.com/sns/userinfo?access_token=%@&openid=%@",[[NSUserDefaults standardUserDefaults] objectForKey:WX_ACCESS_TOKEN],[[NSUserDefaults standardUserDefaults] objectForKey:WX_OPEN_ID]];
    
    NSMutableSet *mgrSet = [NSMutableSet set];
    mgrSet.set = manager.responseSerializer.acceptableContentTypes;
    [mgrSet addObject:@"text/html"];
    //因为微信返回的参数是text/plain 必须加上 会进入fail方法
    [mgrSet addObject:@"text/plain"];
    [mgrSet addObject:@"application/json"];
    manager.responseSerializer.acceptableContentTypes = mgrSet;
    
    [manager GET:url parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"success");
        
        NSLog(@"%@",responseObject);
        NSDictionary *resp = (NSDictionary*)responseObject;
        self->_nicknameLabel.text = resp[@"nickname"];
        self->_sexLabel.text = [resp[@"sex"] intValue] == 1 ? @"男" : @"女";
        self->_addressLabel.text = [NSString stringWithFormat:@"%@%@%@",resp[@"country"],resp[@"province"],resp[@"city"]];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"fail");
        NSLog(@"%@",task.response);
    }];
}

@end
