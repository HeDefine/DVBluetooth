//
//  DVBlePeripheralDelegate.h
//  DVBluetooth
//
//  Created by Devine.He on 2019/5/23.
//  Copyright © 2019 Devine. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DVBlePeripheral;
NS_ASSUME_NONNULL_BEGIN
@protocol DVBlePeripheralDelegate <NSObject>
@optional

/**
 发现特征值回调

 @param peripheral 发现完所有特征值的外设
 @param error 错误信息
 */
- (void)didPeripheralFinishDiscoveredServicesAndCharacteristics:(DVBlePeripheral *)peripheral error:(nullable NSString *)error;

/**
 写入 回调

 @param peripheral 写入的外设
 @param result 写入结果
 */
- (void)didPeripheralWriteData:(DVBlePeripheral *)peripheral
            characteristicUUID:(NSString *)characteristicUUID
                   resultState:(DVBlePeripheralWriteState)result;


/**
 读取回调

 @param peripheral 读取外设
 @param characteristicUUID 读取特征值
 @param data 数据
 @param result 结果
 */
- (void)didPeripheralReadData:(DVBlePeripheral *)peripheral
           characteristicUUID:(NSString *)characteristicUUID
                         data:(nullable NSData *)data
                  resultState:(DVBlePeripheralReadState)result;
@end

NS_ASSUME_NONNULL_END
