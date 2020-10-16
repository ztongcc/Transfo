//
//  TransfoUtil.h
//  Transfo
//
//  Created by Jamis on 2020/9/23.
//  Copyright © 2020 Jemis. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TransfoUtil : NSObject

+ (BOOL)validateResumeData:(NSData *)data;


+ (NSURL *)incompleteDownloadTempPathForDownloadPath:(NSString *)downloadPath;


@end

NS_ASSUME_NONNULL_END
