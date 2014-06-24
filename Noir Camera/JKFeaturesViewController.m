//
//  JKFeaturesViewController.m
//  Noir Camera
//
//  Created by Jay on 5/3/14.
//  Copyright (c) 2014 Zihae. All rights reserved.
//

#import "JKFeaturesViewController.h"
#import "JKPhotoCell.h"
#import <SimpleAuth/SimpleAuth.h>

@interface JKFeaturesViewController ()

@end

@implementation JKFeaturesViewController



- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.collectionView registerClass:[JKPhotoCell class] forCellWithReuseIdentifier:@"photo"];
    self.collectionView.backgroundColor = [UIColor whiteColor];
    
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    self.accessToken = [userDefaults objectForKey:@"accessToken"];
    
    if (self.accessToken == nil) {
        [SimpleAuth authorize:@"instagram" completion:^(NSDictionary *responseObject, NSError *error) {
            self.accessToken = responseObject [@"credentials"][@"token"];
            [userDefaults setObject:self.accessToken forKey:@"accessToken"];
            [userDefaults synchronize];
        
            [self refresh];
        
        }];
        
        
    }else {
        [self refresh];
    }
    
}

- (void)refresh {
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSString *urlString = [[NSString alloc]initWithFormat:@"https://api.instagram.com/v1/tags/snow/media/recent?access_token=%@", self.accessToken ];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        NSData *data = [[NSData alloc]initWithContentsOfURL:location];
        NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        
        self.photos = [responseDictionary valueForKeyPath:@"data"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.collectionView reloadData];
        });
        
    }];
    
    [task resume];
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.photos count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    JKPhotoCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"photo" forIndexPath:indexPath];
    
    cell.backgroundColor = [UIColor lightGrayColor];
    cell.photo = self.photos[indexPath.row];
    return cell;
}

@end
