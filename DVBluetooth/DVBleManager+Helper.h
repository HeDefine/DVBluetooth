//
//  DVBleManager+PeripheralHelper.h
//  DVBluetooth
//
//  Created by Devine.He on 2019/4/23.
//  Copyright © 2019 Devine. All rights reserved.
//

#import "DVBleManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DVBleManager (Helper)


#pragma mark - Sort 排序相关
/**
 获取根据 RSSI和名字排好序的所有设备

 @return 排好序的设备
 */
- (NSArray<DVBlePeripheral *> *)allPeripheralsSorted;


/**
 获取根据 RSSI和名字排好序的 扫描到的设备

 @return 排好序的扫描到的设备
 */
- (NSArray<DVBlePeripheral *> *)scannedPeripheralsSorted;
@end

NS_ASSUME_NONNULL_END
