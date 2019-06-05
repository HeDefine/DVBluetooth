//
//  TableViewController.m
//  DVBluetooth
//
//  Created by Devine.He on 2019/4/22.
//  Copyright © 2019 Devine. All rights reserved.
//

#import "TableViewController.h"
#import "TableViewCell.h"
#import "BedManager.h"

#import "MBProgressHUD.h"

@interface TableViewController () <BedManagerDelegate>


@end
@implementation TableViewController {
    MBProgressHUD *toastHUD;
    MBProgressHUD *loadingHUD;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.clearsSelectionOnViewWillAppear = NO;
    
    toastHUD = [[MBProgressHUD alloc] initWithView:self.view];
    toastHUD.mode = MBProgressHUDModeText;
    toastHUD.offset = CGPointMake(0.f, MBProgressMaxOffset);
    [self.view addSubview:toastHUD];
    
    loadingHUD = [[MBProgressHUD alloc] initWithView:self.view];
    loadingHUD.mode = MBProgressHUDModeIndeterminate;
    [self.view addSubview:loadingHUD];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [BedManager shared].delegate = self;
}


#pragma mark - Button Event
- (IBAction)refreshData:(id)sender {
    [self showLoadingView:@"扫描中..." detailText:nil];
    [[BedManager shared] scanPeripherals];
    [self.tableView reloadData];
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Connected" : @"Searched";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return [[BedManager shared] connectedPeripherals].count;
    } else {
        return [[BedManager shared] scannedPeripheralsSorted].count;
    }
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    static NSString *reuseId = @"tableReuseId";
    TableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseId];
    if (cell == nil) {
        cell = [[TableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseId];
    }
    DVBlePeripheral *peri = nil;
    if (indexPath.section == 0) {
        peri = [[[BedManager shared] connectedPeripherals] objectAtIndex:indexPath.row];
    } else {
        peri = [[[BedManager shared] scannedPeripheralsSorted] objectAtIndex:indexPath.row];
    }
    cell.nameLbl.text = peri.name ? : @"(noName)";
    cell.uuidLbl.text = peri.identifier;
    cell.rssiLbl.text = [NSString stringWithFormat:@"信号:%@",peri.RSSI];
    cell.servicesLbl.text = [NSString stringWithFormat:@"服务数:%d",(int)peri.serviceUUIDs.count];
    cell.accessoryType = peri.isConnected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        DVBlePeripheral *peri = [[[BedManager shared] connectedPeripherals] objectAtIndex:indexPath.row];
        [[BedManager shared] disConnectToPeripheral:peri];
    } else {
        DVBlePeripheral *peri = [[[BedManager shared] scannedPeripheralsSorted] objectAtIndex:indexPath.row];
        [[BedManager shared] connectToPeripheral:peri];
    }
}


#pragma mark - DVBleManagerDelegate
- (void)didBluetoothStateChanged:(DVBleManagerState)state {
    switch (state) {
        case DVBleManagerStatePowerOn:
            [self showToastView:@"蓝牙已打开"];
            break;
        case DVBleManagerStatePowerOff:
            [self.tableView reloadData];
            [self showToastView:@"蓝牙已关闭"];
            break;
        default:
            [self showToastView:@"蓝牙无权限"];
            break;
    }
}

- (void)didScanPeripheralState:(DVBleManagerScanState)state newPeripheral:(DVBlePeripheral *)newPeri {
    switch (state) {
        case DVBleManagerScanBegin:
            [self showLoadingView:@"扫描设备..." detailText:@""];
            [self.tableView reloadData];
            break;
        case DVBleManagerScanning:
            [self hideLoadingView];
            [self.tableView reloadData];
            break;
        case DVBleManagerScanEnd:
            break;
    }
}

#pragma mark - 连接相关回调
/**
 已连接到外设
 */
- (void)didConnectToPeripheral:(DVBlePeripheral *)peripheral state:(DVBleManagerConnectState)state {
    switch (state) {
        case DVBleManagerConnectBegin:
            [self.tableView reloadData];
            if (![DVBleManager shared].isReconnecting) {
                [self showLoadingView:peripheral.name detailText:@"连接中..."];
            }
            break;
        case DVBleManagerConnectDiscovering:
            if (![DVBleManager shared].isReconnecting) {
                [self showLoadingView:peripheral.name detailText:@"连接成功,查询中..."];
            }
            break;
        case DVBleManagerConnectFiltering:
            if (![DVBleManager shared].isReconnecting) {
                [self showLoadingView:peripheral.name detailText:@"配对中..."];
            }
            break;
        case DVBleManagerConnectSuccess:
            if (![DVBleManager shared].isReconnecting) {
                [self hideLoadingView];
            }
            [self.tableView reloadData];
            [self showToastView:[NSString stringWithFormat:@"%@ 连接成功",peripheral.name]];
            [self.navigationController popViewControllerAnimated:YES];
            break;
    }
}

/**
 连接失败并且重连也失败的时候回调 (一般是连接失败或者被动断开连接)
 */
- (void)didConnectFailedToPeripheral:(DVBlePeripheral *)peripheral error:(DVBleManagerConnectError)error {
    if (![DVBleManager shared].isReconnecting) {
        [self hideLoadingView];
    }
    switch (error) {
        case DVBleManagerConnectErrorTimeout:
            [self showToastView:@"设备超出范围或者设备不允许连接"];
            break;
        case DVBleManagerConnectErrorNotParied:
            [self showToastView:@"不是对应的设备"];
            break;
        case DVBleManagerConnectErrorConnectFailed:
            [self showToastView:@"连接失败"];
            break;
        default:
            break;
    }
}

/**
 外设 已经主动断开连接
 */
- (void)didDisConnectedToPeripheral:(DVBlePeripheral *)peripheral isActive:(BOOL)isActive{
    //NSLog(@">>>>>>%@ 断开连接", peripheral.name);
    [self.tableView reloadData];
    [self showToastView:[NSString stringWithFormat:@"%@ 断开连接",peripheral.name]];
}

/**
 重连设备
 */
- (void)didReconnectedToPeripherals:(NSArray<DVBlePeripheral *> *)needReconnectPeripheral status:(DVBleManagerReconnectState)state {
    NSMutableString *periNames = @"".mutableCopy;
    for (DVBlePeripheral *peri in needReconnectPeripheral) {
        if (periNames.length > 0) {
            [periNames appendString:@"\n"];
        }
        [periNames appendString:peri.name];
    }
    switch (state) {
        case DVBleManagerReconnectBegin:
            [self showLoadingView:@"重连中..." detailText:periNames];
            break;
        case DVBleManagerReconnecting:
            [self showLoadingView:@"重连中..." detailText:periNames];
            break;
        case DVBleManagerReconnectEnd:
            [self hideLoadingView];
            break;
    }
}



#pragma mark - HUD
- (void)showToastView:(NSString *)toastText {
    toastHUD.label.text = toastText;
    [toastHUD showAnimated:YES];
    [toastHUD hideAnimated:YES afterDelay:1];
}

- (void)showLoadingView:(NSString *)loadingText detailText:(NSString *)detail {
    loadingHUD.label.text = loadingText;
    loadingHUD.detailsLabel.text = detail;
    [loadingHUD showAnimated:YES];
}

- (void)hideLoadingView {
    [loadingHUD hideAnimated:YES];
}

@end




