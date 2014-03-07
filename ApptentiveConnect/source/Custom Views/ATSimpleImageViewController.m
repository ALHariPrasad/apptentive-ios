//
//  ATSimpleImageViewController.m
//  ApptentiveConnect
//
//  Created by Andrew Wooster on 3/27/11.
//  Copyright 2011 Apptentive, Inc.. All rights reserved.
//

#import "ATSimpleImageViewController.h"
#import "ATCenteringImageScrollView.h"
#import "ATConnect.h"
#import "ATConnect_Private.h"
#import "ATFeedback.h"
#import "ATUtilities.h"

NSString * const ATImageViewChoseImage = @"ATImageViewChoseImage";

#define kATContainerViewTag (5)
#define kATLabelViewTag (6)

@interface ATSimpleImageViewController ()
- (void)chooseImage;
- (void)takePhoto;
- (void)cleanupImageActionSheet;
- (void)dismissImagePickerPopover;
@end

@implementation ATSimpleImageViewController
@synthesize containerView;

- (id)initWithDelegate:(NSObject<ATSimpleImageViewControllerDelegate> *)aDelegate {
	self = [super initWithNibName:@"ATSimpleImageViewController" bundle:[ATConnect resourceBundle]];
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		self.modalPresentationStyle = UIModalPresentationFormSheet;
	}
	if (self != nil) {
		delegate = aDelegate;
	}
	return self;
}

- (void)dealloc {
	[self cleanupImageActionSheet];
	imagePickerPopover.delegate = nil;
	imagePickerPopover = nil;
	delegate = nil;
	scrollView.delegate = nil;
	[scrollView removeFromSuperview];
	scrollView = nil;
	[containerView removeFromSuperview];
	containerView = nil;
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

#pragma mark - View lifecycle
- (void)viewDidLoad {
	[super viewDidLoad];
	self.navigationItem.title = ATLocalizedString(@"Screenshot", @"Screenshot view title");
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCamera target:self action:@selector(takePhoto:)];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(donePressed:)];
}

- (void)setupScrollView {
	if (scrollView) {
		scrollView.delegate = nil;
		[scrollView removeFromSuperview];
		scrollView = nil;
	}
	
	UIImage *defaultScreenshot = nil;
	if (delegate && [delegate respondsToSelector:@selector(defaultImageForImageViewController:)]) {
		defaultScreenshot = [delegate defaultImageForImageViewController:self];
	}
	if (defaultScreenshot) {
		for (UIView *subview in self.containerView.subviews) {
			[subview removeFromSuperview];
		}
		scrollView = [[ATCenteringImageScrollView alloc] initWithImage:defaultScreenshot];
		scrollView.backgroundColor = [UIColor blackColor];
		CGSize boundsSize = self.containerView.bounds.size;
		CGSize imageSize = [scrollView imageView].image.size;
		
		CGFloat xScale = boundsSize.width / imageSize.width;
		CGFloat yScale = boundsSize.height / imageSize.height;
		CGFloat minScale = MIN(xScale, yScale);
		CGFloat maxScale = 2.0;
		
		if (minScale > maxScale) {
			minScale = maxScale;
		}
		scrollView.delegate = self;
		scrollView.bounces = YES;
		scrollView.bouncesZoom = YES;
		scrollView.minimumZoomScale = minScale;
		scrollView.maximumZoomScale = maxScale;
		scrollView.alwaysBounceHorizontal = YES;
		scrollView.alwaysBounceVertical = YES;
		
		[scrollView setZoomScale:minScale];
		scrollView.frame = self.containerView.bounds;
		[self.containerView addSubview:scrollView];
	} else {
		UIView *container = nil;
		UITextView *label = nil;
		if ([self.containerView viewWithTag:kATContainerViewTag]) {
			container = [self.containerView viewWithTag:kATContainerViewTag];
			label = (UITextView *)[self.containerView viewWithTag:kATLabelViewTag];
		} else {
			container = [[UIView alloc] initWithFrame:self.containerView.bounds];
			container.tag = kATContainerViewTag;
			container.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
			container.backgroundColor = [UIColor blackColor];
			label = [[UITextView alloc] initWithFrame:CGRectZero];
			label.tag = kATLabelViewTag;
			label.backgroundColor = [UIColor clearColor];
			label.font = [UIFont boldSystemFontOfSize:16.0];
			label.textColor = [UIColor whiteColor];
			label.userInteractionEnabled = NO;
			label.textAlignment = NSTextAlignmentCenter;
			label.text = ATLocalizedString(@"You can include a screenshot by choosing a photo from your photo library above.\n\nTo take a screenshot, hold down the power and home buttons at the same time.", @"Description of what to do when there is no screenshot.");
		}
		[self.containerView addSubview:container];
		[container sizeToFit];
		[container addSubview:label];
		
		CGFloat labelWidth = container.bounds.size.width - 40.0;
		CGSize labelSize = [label sizeThatFits:CGSizeMake(labelWidth, CGFLOAT_MAX)];
		CGFloat topOffset = floor(labelSize.height/2.0);
		CGRect labelRect = CGRectMake(20, topOffset, labelWidth, labelSize.height);
		label.frame = labelRect;
		label.center = container.center;
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self setupScrollView];
}

- (void)viewDidAppear:(BOOL)animated {
	//NSLog(@"size is: %@", NSStringFromCGRect(self.view.bounds));
}

- (void)viewWillDisappear:(BOOL)animated {
	if (shouldResign) {
		[delegate imageViewControllerWillDismiss:self animated:animated];
		delegate = nil;
	}
}

- (void)viewDidUnload {
	[containerView removeFromSuperview];
	containerView = nil;
	[super viewDidUnload];
}

- (IBAction)donePressed:(id)sender {
	shouldResign = YES;
	[self cleanupImageActionSheet];
	if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
		NSObject<ATSimpleImageViewControllerDelegate> *blockDelegate = delegate;
		[self.navigationController dismissViewControllerAnimated:YES completion:^{
			[blockDelegate imageViewControllerDidDismiss:self];
		}];
	} else {
		if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
			[self dismissViewControllerAnimated:YES completion:NULL];
		} else {
#			pragma clang diagnostic push
#			pragma clang diagnostic ignored "-Wdeprecated-declarations"
			[self dismissModalViewControllerAnimated:YES];
#			pragma clang diagnostic pop
		}
	}
}

- (IBAction)takePhoto:(id)sender {
	ATFeedbackAttachmentOptions options = [delegate attachmentOptionsForImageViewController:self];
	if (options & ATFeedbackAllowTakePhotoAttachment) {
		[self cleanupImageActionSheet];
		[self dismissImagePickerPopover];
		if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
			imageActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:ATLocalizedString(@"Cancel", @"Cancel Button Title") destructiveButtonTitle:nil otherButtonTitles:ATLocalizedString(@"Choose From Library", @"Choose Photo Button Title"), ATLocalizedString(@"Take Photo", @"Take Photo Button Title"), nil];
		} else {
			imageActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:ATLocalizedString(@"Cancel", @"Cancel Button Title") destructiveButtonTitle:nil otherButtonTitles:ATLocalizedString(@"Choose From Library", @"Choose Photo Button Title"), nil];
		}
		
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
			[imageActionSheet showFromBarButtonItem:self.navigationItem.leftBarButtonItem animated:YES];
		} else {
			[imageActionSheet showInView:self.view];
		}
	} else {
		[self chooseImage];
	}
}

#pragma mark UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == 0) {
		[self chooseImage];
	} else if (buttonIndex == 1 && [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
		[self takePhoto];
	}
	if (actionSheet && imageActionSheet && [actionSheet isEqual:imageActionSheet]) {
		imageActionSheet.delegate = nil;
		imageActionSheet = nil;
	}
}

#pragma mark UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
	UIImage *image = nil;
	if ([info objectForKey:UIImagePickerControllerEditedImage]) {
		image = [info objectForKey:UIImagePickerControllerEditedImage];
	} else if ([info objectForKey:UIImagePickerControllerOriginalImage]) {
		image = [info objectForKey:UIImagePickerControllerOriginalImage];
	}
	if (image) {
		[delegate imageViewController:self pickedImage:image fromSource:isFromCamera ? ATFeedbackImageSourceCamera : ATFeedbackImageSourcePhotoLibrary];
		[[NSNotificationCenter defaultCenter] postNotificationName:ATImageViewChoseImage object:self];
	}
	[self setupScrollView];
	
	[self dismissImagePickerPopover];
#	pragma clang diagnostic push
#	pragma clang diagnostic ignored "-Wdeprecated-declarations"
	if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)] && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
		[self dismissViewControllerAnimated:YES completion:^{
			// pass
		}];
	} else if (self.modalViewController) {
		[self.navigationController dismissModalViewControllerAnimated:YES];
	}
#	pragma clang diagnostic pop
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[self dismissImagePickerPopover];
	
#	pragma clang diagnostic push
#	pragma clang diagnostic ignored "-Wdeprecated-declarations"
	if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)] && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
		[self dismissViewControllerAnimated:YES completion:^{
			// pass
		}];
	} else if (self.modalViewController) {
		[self.navigationController dismissModalViewControllerAnimated:YES];
	}
#	pragma clang diagnostic pop
}

#pragma mark Rotation
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	[self setupScrollView];
}

#pragma mark UIScrollViewDelegate
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)aScrollView {
	return [scrollView imageView];
}

#pragma mark UIPopoverControllerDelegate
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
	if (popoverController == imagePickerPopover) {
		imagePickerPopover.delegate = nil;
		imagePickerPopover = nil;
	}
}

#pragma mark Private
- (void)chooseImage {
	isFromCamera = NO;
	shouldResign = NO;
	UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
	imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	imagePicker.delegate = self;
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		if (imagePickerPopover) {
			imagePickerPopover.delegate = nil;
			[imagePickerPopover dismissPopoverAnimated:NO];
			imagePickerPopover = nil;
		}
		imagePickerPopover = [[UIPopoverController alloc] initWithContentViewController:imagePicker];
		imagePickerPopover.delegate = self;

		/*! Fix for iPad crash when authenticating Photo access via UIImagePickerController in a UIPopoverControl from a UIBarButtonItem.
		 http://stackoverflow.com/questions/18939537/uiimagepickercontroller-crash-only-on-ios-7-ipad
		 http://openradar.appspot.com/radar?id=6369788687286272
		 TODO: move back to `presentPopoverFromBarButtonItem:` when crash has been fixed in iOS.
		*/
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && [ATUtilities osVersionGreaterThanOrEqualTo:@"7.0"]) {
			[imagePickerPopover presentPopoverFromRect:self.view.frame inView:self.view permittedArrowDirections:0 animated:YES];
		} else {
			[imagePickerPopover presentPopoverFromBarButtonItem:self.navigationItem.leftBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
		}
	} else if ([self respondsToSelector:@selector(presentViewController:animated:completion:)]) {
		[self presentViewController:imagePicker animated:YES completion:NULL];
	} else {
#		pragma clang diagnostic push
#		pragma clang diagnostic ignored "-Wdeprecated-declarations"
		[self presentModalViewController:imagePicker animated:YES];
#		pragma clang diagnostic pop
	}
}

- (void)takePhoto {
	isFromCamera = YES;
	shouldResign = NO;
	
	[self dismissImagePickerPopover];
	UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
	imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
	imagePicker.delegate = self;
	if ([self respondsToSelector:@selector(presentViewController:animated:completion:)]) {
		[self presentViewController:imagePicker animated:YES completion:NULL];
	} else {
#		pragma clang diagnostic push
#		pragma clang diagnostic ignored "-Wdeprecated-declarations"
		[self presentModalViewController:imagePicker animated:YES];
#		pragma clang diagnostic pop
	}
}

- (void)cleanupImageActionSheet {
	if (imageActionSheet) {
		imageActionSheet.delegate = nil;
		[imageActionSheet dismissWithClickedButtonIndex:-1 animated:NO];
		imageActionSheet = nil;
	}
}

- (void)dismissImagePickerPopover {
	if (imagePickerPopover) {
		[imagePickerPopover dismissPopoverAnimated:YES];
	}
}
@end
