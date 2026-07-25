#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <spawn.h>
#import "FWARootListController.h"
#import <rootless.h>
#include <roothide.h>

extern char **environ;

#define FIXWA_GITHUB_URL   @"https://github.com/0xkuj/FixWANotifs"
#define FIXWA_DONATE_URL   @"https://paypal.me/0xkuj"
#define FIXWA_TWITTER_URL  @"https://www.x.com/0xkuj"

@implementation FWARootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}
	return _specifiers;
}

- (void)performUserspaceReboot {
	pid_t pid = 0;
	char *const argv[] = { "ldrestart", NULL };
	posix_spawn(&pid, jbroot(@"/usr/bin/ldrestart").UTF8String, NULL, NULL, argv, environ);

	UIAlertController *alert = [UIAlertController
		alertControllerWithTitle:@"Manual Userspace Reboot Required"
		message:@"Settings saved. FixWANotifs can't reboot for you here — please perform a userspace reboot manually (e.g. from the Dopamine app) to apply the changes."
		preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)applyAndReboot {
	UIAlertController *confirm = [UIAlertController
		alertControllerWithTitle:@"Apply Settings"
		message:@"This will save your settings and userspace-reboot the device now."
		preferredStyle:UIAlertControllerStyleAlert];
	[confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	[confirm addAction:[UIAlertAction actionWithTitle:@"Apply & Reboot"
		style:UIAlertActionStyleDestructive
		handler:^(UIAlertAction *action) { [self performUserspaceReboot]; }]];
	[self presentViewController:confirm animated:YES completion:nil];
}

- (void)openGithub {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:FIXWA_GITHUB_URL]
	                                   options:@{} completionHandler:nil];
}

- (void)openDonate {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:FIXWA_DONATE_URL]
	                                   options:@{} completionHandler:nil];
}


-(void)openTwitter {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:FIXWA_TWITTER_URL]
	                                   options:@{} completionHandler:nil];
}
@end
