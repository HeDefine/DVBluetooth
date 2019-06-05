//
//  TableViewCell.h
//  DVBluetooth
//
//  Created by Devine.He on 2019/4/23.
//  Copyright © 2019 Devine. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *nameLbl;
@property (weak, nonatomic) IBOutlet UILabel *uuidLbl;
@property (weak, nonatomic) IBOutlet UILabel *servicesLbl;
@property (weak, nonatomic) IBOutlet UILabel *rssiLbl;

@end

NS_ASSUME_NONNULL_END
