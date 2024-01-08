//
//  BaseModel.m
//  gamebox_sk
//
//  Created by 赵隆杰 on 2021/12/10.
//

#import "BaseModel.h"

@implementation BaseModel
- (instancetype)copy
{
    NSDictionary *dic = self.mj_keyValues;
    BaseModel *model = [[self class] mj_objectWithKeyValues:dic];
    return model;
}

// 模型属性: JSON key, MJExtension 会自动将 JSON 的 key 替换为你模型中需要的属性
+ (NSDictionary *)mj_replacedKeyFromPropertyName
{
    return @{
        
             // 定义model时，如果文档上写的key为id，model要声明的property为 id_,这里会自动处理
             // model转成dic时，会自动转成 @"id"
             @"id_":@"id",
             };

}


/*   模型字典转换统一用MJ的方法
 *   1.字典转模型 Model *model = [Model mj_objectWithKeyValues:dic];
 *   2.模型转字典  NSDictionary *dic = model.mj_keyValues；
 *   3.定义模型有id的字段统一定义成 id_，基类里会处理
 *   4.字典里有list的里面要转对象，在Model.m 中实现
     + (NSDictionary *)mj_objectClassInArray
     {
             return @{
                      @"items":@"YJModelItem"
                      };
     }
 */
@end
