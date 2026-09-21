#import <UIKit/UIKit.h>
#import <objc/runtime.h>

__attribute__((constructor))
static void teleflow_setup(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = [UIViewController class];
        Method orig = class_getInstanceMethod(cls, @selector(viewDidLoad));
        Method swiz = class_getInstanceMethod(cls, @selector(teleflow_viewDidLoad));
        if (orig && swiz) {
            method_exchangeImplementations(orig, swiz);
            NSLog(@"[TeleFlow] viewDidLoad swizzled");
        }
    });
}

@interface UIViewController (TeleFlowHook)
@end

@implementation UIViewController (TeleFlowHook)

- (void)teleflow_viewDidLoad {
    [self teleflow_viewDidLoad];

    NSString *name = NSStringFromClass([self class]);
    if (![name containsString:@"Settings"]) return;
    if (![name containsString:@"Controller"]) return;
    if ([name containsString:@"TeleFlow"]) return;
    if (self.navigationController == nil) return;

    for (UIBarButtonItem *b in self.navigationItem.rightBarButtonItems) {
        if ([b.title isEqualToString:@"TeleFlow"]) return;
    }

    UIBarButtonItem *btn = [[UIBarButtonItem alloc] initWithTitle:@"TeleFlow"
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(teleflow_openSettings)];
    NSMutableArray *items = [NSMutableArray arrayWithArray:self.navigationItem.rightBarButtonItems ?: @[]];
    [items insertObject:btn atIndex:0];
    self.navigationItem.rightBarButtonItems = items;
    NSLog(@"[TeleFlow] button injected into %@", name);
}

- (void)teleflow_openSettings {
    Class cls = NSClassFromString(@"TeleFlow.TeleFlowSettingsScreen");
    if (!cls) {
        NSLog(@"[TeleFlow] settings screen class not found");
        return;
    }
    UIViewController *vc = [[cls alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
