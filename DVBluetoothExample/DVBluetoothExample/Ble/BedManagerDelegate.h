//
//  OREBedManagerDelegate.h
//  DVBluetooth
//
//  Created by Devine.He on 2019/6/5.
//  Copyright © 2019 Devine. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DVBleManagerDelegate.h"
@protocol BedManagerDelegate <DVBleManagerDelegate>
@optional
/**
 写入结果

 @param result 特征值写入结果
 */
- (void)didWriteDataResultState:(DVBlePeripheralWriteState)result;

/**
 读取回调

 @param data 数据
 @param result 结果
 */
- (void)didReadData:(NSData *)data resultState:(DVBlePeripheralReadState)result;

@end

