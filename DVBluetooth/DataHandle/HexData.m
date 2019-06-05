//
//  HexData.m
//  SleepMonitor
//
//  Created by Devine.He on 2017/8/1.
//  Copyright © 2017年 refinedchina. All rights reserved.
//

#import "HexData.h"

@implementation HexData

+ (NSData*)hexStrToData:(NSString *)str {
    NSMutableData* data = [NSMutableData data];
    for (int idx = 0; idx+2 <= str.length; idx+=2) {
        NSRange range = NSMakeRange(idx, 2);
        NSString* hexStr = [str substringWithRange:range];
        NSScanner* scanner = [NSScanner scannerWithString:hexStr];
        unsigned int intValue;
        [scanner scanHexInt:&intValue];
        [data appendBytes:&intValue length:1];
    }
    return data;
}

/**
 将数据转换成相应的十六进制字符串
 */
+ (NSString *)dataToHexStr:(NSData *)data {
    return [self dataToHexStr:data seperator:nil];
}

/**
 将数据转换成相应的十六进制字符串
 */
+ (NSString *)dataToHexStr:(NSData *)data seperator:(NSString *)seperator {
    NSMutableString *hexStr = [[NSMutableString alloc] init];
    Byte *bytes = (Byte *)data.bytes;
    for (int i = 0; i < data.length; i ++) {
        NSString *hex = [NSString stringWithFormat:@"%02x",bytes[i]];
        [hexStr appendString:hex];
        if (seperator) {
            [hexStr appendString:seperator];
        }
    }
    return hexStr;
}

+ (uint8_t)checksum: (Byte *)data length:(int)len {
    uint8_t checkSum = 0;
    for (int i = 0; i < len-1; i++) {
        checkSum += data[i];
    }
    return ~checkSum;
}

+ (NSData *)hexIntToData:(int)Id {
    //用4个字节接收
    Byte bytes[4];
    bytes[0] = (Byte)(Id>>24);
    bytes[1] = (Byte)(Id>>16);
    bytes[2] = (Byte)(Id>>8);
    bytes[3] = (Byte)(Id);
    NSData *data = [NSData dataWithBytes:bytes length:4];
    return data;
}


+ (NSData *)byteFromUInt8:(uint8_t)val isReverse:(BOOL)isReverse {
    NSMutableData *valData = [[NSMutableData alloc] init];
    
    unsigned char valChar[1];
    valChar[0] = 0xff & val;
    [valData appendBytes:valChar length:1];
    return isReverse ? [self dataWithReverse:valData] :valData;
}

+ (NSData *)bytesFromUInt16:(uint16_t)val isReverse:(BOOL)isReverse {
    NSMutableData *valData = [[NSMutableData alloc] init];
    
    unsigned char valChar[2];
    valChar[0] = 0xff & val;
    valChar[1] = (0xff00 & val) >> 8;
    [valData appendBytes:valChar length:2];
    
    return isReverse ? [self dataWithReverse:valData] : valData;
}

+ (NSData *)bytesFromUInt32:(uint32_t)val isReverse:(BOOL)isReverse {
    NSMutableData *valData = [[NSMutableData alloc] init];
    unsigned char valChar[4];
    valChar[0] = 0xff & val;
    valChar[1] = (0xff00 & val) >> 8;
    valChar[2] = (0xff0000 & val) >> 16;
    valChar[3] = (0xff000000 & val) >> 24;
    [valData appendBytes:valChar length:4];
    return isReverse ? [self dataWithReverse:valData] : valData;
}

+ (uint8_t)uint8FromBytes:(NSData *)fData {
    NSAssert(fData.length == 1, @"uint8FromBytes: (data length != 1)");
    NSData *data = fData;
    uint8_t val = 0;
    [data getBytes:&val length:1];
    return val;
}

+ (uint16_t)uint16FromBytes:(NSData *)fData{
    NSAssert(fData.length == 2, @"uint16FromBytes: (data length != 2)");
    NSData *data = [self dataWithReverse:fData];;
    uint16_t val0 = 0;
    uint16_t val1 = 0;
    [data getBytes:&val0 range:NSMakeRange(0, 1)];
    [data getBytes:&val1 range:NSMakeRange(1, 1)];
    
    uint16_t dstVal = (val0 & 0xff) + ((val1 << 8) & 0xff00);
    return dstVal;
}

+ (uint32_t)uint32FromBytes:(NSData *)fData {
    NSAssert(fData.length == 4, @"uint32FromBytes: (data length != 4)");
    NSData *data = [self dataWithReverse:fData];
    
    uint32_t val0 = 0;
    uint32_t val1 = 0;
    uint32_t val2 = 0;
    uint32_t val3 = 0;
    [data getBytes:&val0 range:NSMakeRange(0, 1)];
    [data getBytes:&val1 range:NSMakeRange(1, 1)];
    [data getBytes:&val2 range:NSMakeRange(2, 1)];
    [data getBytes:&val3 range:NSMakeRange(3, 1)];
    
    uint32_t dstVal = (val0 & 0xff) + ((val1 << 8) & 0xff00) + ((val2 << 16) & 0xff0000) + ((val3 << 24) & 0xff000000);
    return dstVal;
}

//反转字节
+ (NSData *)dataWithReverse:(NSData *)srcData {
    NSUInteger byteCount = srcData.length;
    NSMutableData *dstData = [[NSMutableData alloc] initWithData:srcData];
    NSUInteger halfLength = byteCount / 2;
    
    for (NSUInteger i=0; i<halfLength; i++) {
        NSRange begin = NSMakeRange(i, 1);
        NSRange end = NSMakeRange(byteCount - i - 1, 1);
        NSData *beginData = [srcData subdataWithRange:begin];
        NSData *endData = [srcData subdataWithRange:end];
        [dstData replaceBytesInRange:begin withBytes:endData.bytes];
        [dstData replaceBytesInRange:end withBytes:beginData.bytes];
    }
    return dstData;
}

@end

@implementation NSString (HexData)

+ (instancetype) hexStringFromData:(NSData *)data {
    return [HexData dataToHexStr:data];
}

+ (instancetype)hexStringFromData:(NSData *)data seperator:(NSString *)seperator {
    return [HexData dataToHexStr:data seperator:seperator];
}

@end

@implementation NSData (HexData)

+ (instancetype)dataFromHexString:(NSString *)hexStr {
    return [HexData hexStrToData:hexStr];
}

@end
