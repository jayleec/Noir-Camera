//
//  JKPhotoCell.m
//  Noir Camera
//
//  Created by Jay on 5/3/14.
//  Copyright (c) 2014 Zihae. All rights reserved.
//

#import "JKPhotoCell.h"
#import <SAMCache/SAMCache.h>

@implementation JKPhotoCell

- (void)setPhoto:(NSDictionary *)photo {
    _photo = photo;
    
    NSURL *url = [[NSURL alloc]initWithString:_photo[@"images"][@"thumbnail"][@"url"] ];
    
    [self downloadWithURL:url];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.imageView = [[UIImageView alloc]init];
        self.imageView.image = [UIImage imageNamed:@"testImage"];
    
        [self.contentView addSubview:self.imageView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.imageView.frame = self.contentView.bounds;
}

- (void)downloadWithURL:(NSURL *)url {
    
    NSString *key = [[NSString alloc]initWithFormat:@"%@-thumbnail", self.photo[@"id"] ];
    UIImage *photo = [[SAMCache sharedCache]imageForKey:key];
    
    if (photo) {
        self.imageView.image = photo;
        return;
    }
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        
        NSData *data = [NSData dataWithContentsOfURL:location];
        UIImage *photo = [UIImage imageWithData:data];
        [[SAMCache sharedCache]setImage:photo forKey:key];
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.imageView.image = photo;
        });
    }];
    
    [task resume];
}

@end












