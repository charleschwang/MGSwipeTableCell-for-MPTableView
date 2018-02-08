//
//  MPTableViewSection.h
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableView.h"

#define MPTableViewMaxCount 7883507
#define MPTableViewMaxSize 7883507.0

typedef struct struct_MPIndexPath {
    NSInteger section, row;
} MPIndexPathStruct;

@interface MPTableViewPosition : NSObject<NSCopying>
@property (nonatomic, assign) CGFloat beginPos;
@property (nonatomic, assign) CGFloat endPos;
+ (instancetype)positionWithBegin:(CGFloat)begin toEnd:(CGFloat)end;

@end

#pragma mark -

typedef NS_ENUM(NSInteger, MPSectionType) {
    MPSectionTypeHeader = NSIntegerMin + 32, MPSectionTypeFooter = NSIntegerMax - 32
};

typedef NS_ENUM(NSInteger, MPTableViewUpdateType) {
    MPTableViewUpdateAdjust,
    MPTableViewUpdateDelete,
    MPTableViewUpdateInsert,
    MPTableViewUpdateReload,
    MPTableViewUpdateMoveIn,
    MPTableViewUpdateMoveOut
};

#define MPTableViewUpdateTypeStable(_type_) (_type_ == MPTableViewUpdateInsert || _type_ == MPTableViewUpdateMoveIn)
#define MPTableViewUpdateTypeUnstable(_type_) (_type_ == MPTableViewUpdateDelete || _type_ == MPTableViewUpdateMoveOut || _type_ == MPTableViewUpdateReload)

UIKIT_EXTERN NSExceptionName const MPTableViewException;
UIKIT_EXTERN NSExceptionName const MPTableViewUpdateException;

#define MPTableViewThrowUpdateException(_exception_) @throw [NSException exceptionWithName:MPTableViewUpdateException reason:_exception_ userInfo:nil]

@class MPTableViewSection;

@interface MPTableViewUpdateBase : NSObject {
@package
    NSMutableIndexSet *_existingStableIndexes;
    NSMutableIndexSet *_existingUnstableIndexes;

    NSInteger _differ;
}
@property (nonatomic, assign) NSUInteger originCount;
@property (nonatomic, assign) NSUInteger newCount;

- (BOOL)formatNodesStable:(BOOL)countCheckIgnored; // For example, a section with 5 cells, it is unable to insert 5 after delete 0.

@end

#pragma mark -

@interface MPTableView (MPTableView_UpdatePrivate)

@property (nonatomic, assign) CGFloat _updateDeleteOriginTopPosition;
@property (nonatomic, assign) CGFloat _updateInsertOriginTopPosition;

- (NSMutableArray *)_ignoredUpdateActions; // insertion and movement

- (MPIndexPathStruct)__beginIndexPath;
- (MPIndexPathStruct)__endIndexPath;

- (BOOL)__isContentMoving;

- (MPTableViewSection *)__updateGetSectionAt:(NSInteger)section;

- (CGFloat)__updateInsertCellHeightAtIndexPath:(MPIndexPath *)indexPath;
- (CGFloat)__updateMoveInCellHeightAtIndexPath:(MPIndexPath *)indexPath originIndexPath:(MPIndexPath *)originIndexPath originHeight:(CGFloat)originHeight withDistance:(CGFloat)distance;
- (CGFloat)__updateGetHeaderHeightInSection:(MPTableViewSection *)section fromOriginSection:(NSInteger)originSection withOffset:(CGFloat)offset force:(BOOL)force;
- (CGFloat)__updateGetFooterHeightInSection:(MPTableViewSection *)section fromOriginSection:(NSInteger)originSection withOffset:(CGFloat)offset force:(BOOL)force;

- (CGFloat)__rebuildCellAtSection:(NSInteger)section fromOriginSection:(NSInteger)originSection atIndex:(NSInteger)index;

- (BOOL)__updateNeedToAnimateSection:(MPTableViewSection *)section updateType:(MPTableViewUpdateType)type andOffset:(CGFloat)offset;

//

- (void)__updateSection:(NSInteger)originSection deleteCellAtIndex:(NSInteger)index withAnimation:(MPTableViewRowAnimation)animation isSectionAnimation:(MPTableViewSection *)sectionPosition;
- (BOOL)__updateSection:(NSInteger)section insertCellAtIndex:(NSInteger)index withAnimation:(MPTableViewRowAnimation)animation isSectionAnimation:(MPTableViewSection *)sectionPosition;

- (BOOL)__updateSection:(NSInteger)section moveInCellAtIndex:(NSInteger)index fromOriginIndexPath:(MPIndexPath *)originIndexPath withOriginHeight:(CGFloat)originHeight withDistance:(CGFloat)distance;

- (BOOL)__updateSection:(NSInteger)section originSection:(NSInteger)originSection adjustCellAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex; // selectedIndexPaths change

- (CGFloat)__updateSection:(NSInteger)section originSection:(NSInteger)originSection adjustCellAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex withOffset:(CGFloat)cellOffset;

//
- (void)__updateDeleteSectionViewAtIndex:(NSInteger)index withType:(MPSectionType)type withAnimation:(MPTableViewRowAnimation)animation withDeleteSection:(MPTableViewSection *)deleteSection;
- (BOOL)__updateInsertSectionViewAtIndex:(NSInteger)index withType:(MPSectionType)type withAnimation:(MPTableViewRowAnimation)animation withInsertSection:(MPTableViewSection *)insertSection;

- (BOOL)__updateMoveInSectionViewAtIndex:(NSInteger)index fromOriginIndex:(NSInteger)originIndex withType:(MPSectionType)type withOriginHeight:(CGFloat)originHeight withDistance:(CGFloat)distance;

- (BOOL)__updateAdjustSectionViewAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex withType:(MPSectionType)type;

- (void)__updateAdjustSectionViewAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex withType:(MPSectionType)type withOriginHeight:(CGFloat)originHeight withSectionOffset:(CGFloat)sectionOffset;

//
- (BOOL)__isEstimatedMode;

- (BOOL)__estimatedNeedToAdjustAt:(MPTableViewSection *)section withOffset:(CGFloat)offset;

- (CGFloat)__estimateAdjustSectionViewHeight:(MPSectionType)type inSection:(MPTableViewSection *)section;

- (CGFloat)__estimateAdjustCellAtSection:(NSInteger)section atIndex:(NSInteger)originIndex withOffset:(CGFloat)cellOffset;
- (void)__estimateAdjustSectionViewAtSection:(NSInteger)originIndex withType:(MPSectionType)type;

@end

#pragma mark -

@interface MPTableViewEstimatedManager : NSObject

@property (nonatomic, weak) NSMutableArray *sections;
@property (nonatomic, weak) MPTableView *delegate;

- (CGFloat)startUpdate:(MPIndexPathStruct)firstIndexPath;

@end

#pragma mark -

@interface MPTableViewUpdateManager : MPTableViewUpdateBase

@property (nonatomic, weak) NSMutableArray *sections;
@property (weak, readonly) MPTableView *delegate;

@property (nonatomic, assign) NSUInteger moveFromSection;
@property (nonatomic, assign) NSUInteger moveToSection; // optimize

- (BOOL)hasUpdateNodes;

+ (MPTableViewUpdateManager *)managerWithDelegate:(MPTableView *)delegate andSections:(NSMutableArray *)sections;
- (void)resetManager;

- (BOOL)addMoveOutSection:(NSUInteger)section;
- (BOOL)addMoveInSection:(NSUInteger)section withOriginIndex:(NSInteger)originSection;

- (BOOL)addDeleteSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutIndexPath:(MPIndexPath *)indexPath;
- (BOOL)addMoveInIndexPath:(MPIndexPath *)indexPath withFrame:(CGRect)frame withOriginIndexPath:(MPIndexPath *)originIndexPath;

- (BOOL)addDeleteIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;

- (CGFloat)startUpdate;

@end

#pragma mark -

@interface MPTableViewUpdatePart : MPTableViewUpdateBase

- (BOOL)addMoveOutRow:(NSUInteger)row;
- (BOOL)addMoveInRow:(NSUInteger)row withFrame:(CGRect)frame withOriginIndexPath:(MPIndexPath *)originIndexPath;

- (BOOL)addDeleteRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation;

@end

#pragma mark -

@interface MPTableViewSection : MPTableViewPosition
@property (nonatomic, assign) NSUInteger section;
@property (nonatomic, assign) CGFloat headerHeight;
@property (nonatomic, assign) CGFloat footerHeight;
@property (nonatomic, assign) NSUInteger numberOfRows;

@property (nonatomic, strong) MPTableViewUpdatePart *updatePart;

@property (nonatomic, assign) CGFloat moveOutHeight;

+ (instancetype)section;
- (void)resetSection;

- (void)addRowWithPosition:(CGFloat)position;
- (CGFloat)rowPositionBeginAt:(NSInteger)index;
- (CGFloat)rowHeightAt:(NSInteger)index;
- (CGFloat)rowPositionEndAt:(NSInteger)index;
- (NSInteger)rowAtContentOffset:(CGFloat)contentOffset;

- (void)setPositionOffset:(CGFloat)offset;

- (MPTableViewSection *)rebuildAndBackup:(MPTableView *)updateDelegate fromOriginSection:(NSInteger)originSection withDistance:(CGFloat)distance;

- (CGFloat)updateUsingPartWithDelegate:(MPTableView *)updateDelegate toSection:(NSInteger)newSection withOffset:(CGFloat)offset needCallback:(BOOL)callback;
- (CGFloat)updateWithDelegate:(MPTableView *)updateDelegate toSection:(NSInteger)newSection withOffset:(CGFloat)offset needCallback:(BOOL)callback;

- (CGFloat)updateEstimatedWith:(MPTableView *)updateDelegate beginIndex:(NSInteger)beginIndex withOffset:(CGFloat)offset needCallback:(BOOL)callback;

@end