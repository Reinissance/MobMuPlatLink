
#import "SceneViewController.h"

@interface contentMenu: UIControl <UITableViewDataSource, UITableViewDelegate>
@property (strong, nonatomic) NSString *titleString;
@property (strong, nonatomic) NSString *address;
@property (strong, nonatomic) NSString *docsDir;
@property (strong, nonatomic) NSString *subfolder;
- (id)initWithTitle: (NSString *) title andAddress: (NSString*) address inFolder: (nullable NSString *) subfolder;
- (void) showMenuWithContent: (NSMutableArray *) content  withDocsDir: (NSString*) dir fromViewController: (SceneViewController*) viewController;
@end
