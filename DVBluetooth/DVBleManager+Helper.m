//
//  DVBleManager+PeripheralHelper.m
//  DVBluetooth
//
//  Created by Devine.He on 2019/4/23.
//  Copyright © 2019 Devine. All rights reserved.
//

#import "DVBleManager+Helper.h"

@implementation DVBleManager (Helper)

- (NSArray<DVBlePeripheral *> *)allPeripheralsSorted {
    return [self.allPeripherals sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
}

- (NSArray<DVBlePeripheral *> *)scannedPeripheralsSorted {
    return [self.scannedPeripherals sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
}
@end
