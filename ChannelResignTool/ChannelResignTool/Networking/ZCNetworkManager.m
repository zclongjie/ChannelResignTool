//
//  ZCNetworkManager.m
//  qipajuhe
//
//  Created by 7pagame on 2018/11/6.
//  Copyright © 2018年 Vanney. All rights reserved.
//

#import "ZCNetworkManager.h"

NSString *const ResponseErrorKey = @"com.alamofire.serialization.response.error.response";
NSInteger const Interval = 10;

@interface ZCNetworkManager()

@end

@implementation ZCNetworkManager

+ (void)downloadWithUrl:(NSString *)url toPath:(NSString *)toPath fileNameLast:(NSString *)fileNameLast success:(SuccessBlock)success failure:(FailureBlock)failure {
    NSURL *URL = [NSURL URLWithString:url];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithRequest:request completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error == nil) {
            //默认把数据写到磁盘中：tmp/...随时可能被删除
//            NSLog(@"location= %@", location);
            //转移文件
            NSString *fileName = response.suggestedFilename;
            if (fileNameLast) {
                NSString *deletingPathExtension = fileName.stringByDeletingPathExtension;
                NSString *pathExtension = fileName.pathExtension;
                fileName = [[deletingPathExtension stringByAppendingString:fileNameLast] stringByAppendingPathExtension:pathExtension];
            }
            NSString *filePath = [toPath stringByAppendingPathComponent:fileName];
//            NSLog(@"filePath = %@",filePath);
            NSURL *toURL = [NSURL fileURLWithPath:filePath];
            [[NSFileManager defaultManager] moveItemAtURL:location toURL:toURL error:nil];

            success(filePath);
        } else {
            NSString *ErrorCode = [self showErrorInfoWithStatusCode:error.code];
            failure(ErrorCode);
        }

    }];
    [downloadTask resume];
}

//原生GET网络请求
+ (void)getWithURL:(NSString *)url Params:(NSDictionary *)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    //完整URL
    NSString *urlString = [NSString string];
    if (params) {
        //参数拼接url
        NSString *paramStr = [self dealWithParam:params];
        urlString = [NSString stringWithFormat:@"%@?%@",url,paramStr];
    }else{
        urlString = url;
    }
    
    NSString *pathStr = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:pathStr]];
    request.timeoutInterval = Interval;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (data) {
               
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
                success(dict);
            }else{
                NSHTTPURLResponse *httpResponse = error.userInfo[ResponseErrorKey];
                
                if (httpResponse.statusCode != 0) {
                    
                    NSString *ResponseStr = [self showErrorInfoWithStatusCode:httpResponse.statusCode];
                    failure(ResponseStr);
                    
                } else {
                    NSString *ErrorCode = [self showErrorInfoWithStatusCode:error.code];
                    failure(ErrorCode);
                }
            }
            
        });
    }];
    
    [task resume];
}

//原生POST请求
+ (void)PostWithURL:(NSString *)url Params:(NSDictionary *)params success:(SuccessBlock)success failure:(FailureBlock)failure {
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    
    //把字典中的参数进行拼接
    NSString *body = [self dealWithParam:params];
    NSData *bodyData = [body dataUsingEncoding:NSUTF8StringEncoding];
    
    //设置请求体
    [request setHTTPBody:bodyData];
    //设置本次请求的数据请求格式
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    // 设置本次请求请求体的长度(因为服务器会根据你这个设定的长度去解析你的请求体中的参数内容)
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)bodyData.length] forHTTPHeaderField:@"Content-Length"];
    //设置请求最长时间
    request.timeoutInterval = Interval;

    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (data) {
            //利用iOS自带原生JSON解析data数据 保存为Dictionary
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
//            NSString *msg = [NSString stringWithFormat:@"%@", dict[@"msg"]];
//            NSString *code = [NSString stringWithFormat:@"%@", dict[@"code"]];
//            if ([code isEqualToString:@"400"]) {
//
//            }
             
            success(dict);
            
        }else{
            NSHTTPURLResponse *httpResponse = error.userInfo[ResponseErrorKey];
            
            if (httpResponse.statusCode != 0) {
                
                NSString *ResponseStr = [self showErrorInfoWithStatusCode:httpResponse.statusCode];
                failure(ResponseStr);
                
            } else {
                NSString *ErrorCode = [self showErrorInfoWithStatusCode:error.code];
                failure(ErrorCode);
            }
        }
    }];
    [task resume];
}

#pragma mark -- 拼接参数
+ (NSString *)dealWithParam:(NSDictionary *)param
{
    NSArray *allkeys = [param allKeys];
    NSMutableString *result = [NSMutableString string];
    
    for (NSString *key in allkeys) {
        NSString *string = [NSString stringWithFormat:@"%@=%@&", key, param[key]];
        [result appendString:string];
    }
    NSString *str = [NSString stringWithFormat:@"%@",[result substringWithRange:NSMakeRange(0, [result length] - 1)]];

    return str;
}

#pragma mark
+ (NSString *)showErrorInfoWithStatusCode:(NSInteger)statusCode{
    
    NSString *message = nil;
    switch (statusCode) {
        case 401: {
            
        }
            break;
            
        case 500: {
            message = @"服务器异常！";
        }
            break;
            
        case -1001: {
            message = @"网络请求超时，请稍后重试！";
        }
            break;
            
        case -1002: {
            message = @"不支持的URL！";
        }
            break;
            
        case -1003: {
            message = @"未能找到指定的服务器！";
        }
            break;
            
        case -1004: {
            message = @"服务器连接失败！";
        }
            break;
            
        case -1005: {
            message = @"连接丢失，请稍后重试！";
        }
            break;
            
        case -1009: {
            message = @"互联网连接似乎是离线！";
        }
            break;
            
        case -1012: {
            message = @"操作无法完成！";
        }
            break;
            
        default: {
            message = @"网络请求发生未知错误，请稍后再试！";
        }
            break;
    }
    return message;
    
}

@end
