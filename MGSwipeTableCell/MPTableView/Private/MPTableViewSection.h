//
//  MPTableViewSection.h
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableView.h"

#ifndef __MPTV_DEFINE
#define __MPTV_DEFINE

#define MPTV_EXCEPTION(_reason_) @throw [NSException exceptionWithName:NSGenericException reason:(_reason_) userInfo:nil];

typedef NS_ENUM(NSInteger, MPSectionViewType) {
    MPSectionHeader = NSIntegerMin + 32, MPSectionFooter = NSIntegerMin + 64
};

const CGFloat MPTableViewInvalidFloat = -87853507.0;

#define MPTV_IS_HEADER(_row_) ((_row_) == MPSectionHeader)
#define MPTV_IS_FOOTER(_row_) ((_row_) == MPSectionFooter)
#define MPTV_ROW_LESS(_row1_, _row2_) (((_row1_) == (_row2_)) ? NO : (MPTV_IS_HEADER(_row1_) ? YES : MPTV_IS_HEADER(_row2_) ? NO : ((NSUInteger)_row1_) < ((NSUInteger)_row2_)))
#define MPTV_ROW_MORE(_row1_, _row2_) (((_row1_) == (_row2_)) ? NO : (MPTV_IS_HEADER(_row1_) ? NO : MPTV_IS_HEADER(_row2_) ? YES : ((NSUInteger)_row1_) > ((NSUInteger)_row2_)))

typedef NS_ENUM(NSInteger, MPTableViewUpdateType) {
    MPTableViewUpdateDelete,
    MPTableViewUpdateInsert,
    MPTableViewUpdateReload,
    MPTableViewUpdateMoveOut,
    MPTableViewUpdateMoveIn,
    MPTableViewUpdateAdjust
};

#define MPTV_UPDATE_TYPE_IS_STABLE(_type_) ((_type_) == MPTableViewUpdateInsert || (_type_) == MPTableViewUpdateMoveIn)
#define MPTV_UPDATE_TYPE_IS_UNSTABLE(_type_) ((_type_) == MPTableViewUpdateDelete || (_type_) == MPTableViewUpdateMoveOut || (_type_) == MPTableViewUpdateReload)

#endif

#pragma mark -

@interface MPTableViewPosition : NSObject<NSCopying>
@property (nonatomic) CGFloat startPos;
@property (nonatomic) CGFloat endPos;
+ (instancetype)positionStart:(CGFloat)start toEnd:(CGFloat)end;

@end

#pragma mark -

@class MPTableViewSection;

@interface MPTableViewUpdateBase : NSObject {
    @package
    NSMutableIndexSet *_existingStableIndexes;
    NSMutableIndexSet *_existingUnstableIndexes;
    
    NSInteger _differ;
}
@property (nonatomic) NSInteger lastCount;
@property (nonatomic) NSInteger newCount;

- (BOOL)prepareToUpdateThenNeedToCheck:(BOOL)needToCheck; // For example, a section has 5 rows, it is unable to insert 5 after delete 0.

@end

#pragma mark -

@interface MPTableView (MPTableView_UpdatePrivate)

- (NSMutableArray *)_updateExecutionActions; // for insertion and movement

- (NSInteger)_beginSection;
- (NSInteger)_beginRow;
- (NSInteger)_endSection;
- (NSInteger)_endRow;

- (CGFloat)_updateLastDeletionOriginY;
- (void)_setUpdateLastDeletionOriginY:(CGFloat)updateLastDeletionOriginY;
- (CGFloat)_updateLastInsertionOriginY;
- (void)_setUpdateLastInsertionOriginY:(CGFloat)updateLastInsertionOriginY;

- (BOOL)_hasDraggingCell;

- (MPTableViewSection *)_updateBuildSection:(NSInteger)section;

- (CGFloat)_updateGetInsertCellHeightInSection:(NSInteger)section atRow:(NSInteger)row;
- (CGFloat)_updateGetMoveInCellDifferInSection:(NSInteger)section atRow:(NSInteger)row fromLastIndexPath:(NSIndexPath *)lastIndexPath withLastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance;
- (CGFloat)_updateGetAdjustCellDifferInSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withOffset:(CGFloat)offset needToLoadHeight:(BOOL *)needToLoadHeight;
- (CGFloat)_updateGetHeaderHeightInSection:(MPTableViewSection *)section fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isMovement:(BOOL)isMovement;
- (CGFloat)_updateGetFooterHeightInSection:(MPTableViewSection *)section fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isMovement:(BOOL)isMovement;

- (CGFloat)_updateGetRebuildCellDifferInSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection withDistance:(CGFloat)distance needToLoadHeight:(BOOL *)needToLoadHeight;

- (BOOL)_updateNeedToDisplaySection:(MPTableViewSection *)section withUpdateType:(MPTableViewUpdateType)type withOffset:(CGFloat)offset;
- (BOOL)_updateNeedToAdjustCellsFromLastSection:(NSInteger)lastSection;
- (BOOL)_updateNecessaryToAdjustSection:(MPTableViewSection *)section withOffset:(CGFloat)offset;

- (BOOL)_updateNeedToAdjustCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow;
- (BOOL)_updateNeedToAdjustSectionViewInLastSection:(NSInteger)lastSection withType:(MPSectionViewType)type;

// update cells
- (void)_updateDeleteCellInSection:(NSInteger)lastSection atRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation inSectionPosition:(MPTableViewSection *)sectionPosition;
- (void)_updateInsertCellToSection:(NSInteger)section atRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation inSectionPosition:(MPTableViewSection *)sectionPosition withLastInsertionOriginY:(CGFloat)updateLastInsertionOriginY;
- (void)_updateMoveCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withLastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance;
- (void)_updateAdjustCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withLastHeight:(CGFloat)lastHeight withOffset:(CGFloat)offset;

// update cells and headers/footers
- (void)_updateDeleteSectionViewInSection:(NSInteger)section withType:(MPSectionViewType)type withAnimation:(MPTableViewRowAnimation)animation withDeleteSection:(MPTableViewSection *)deleteSection;
- (void)_updateInsertSectionViewToSection:(NSInteger)section withType:(MPSectionViewType)type withAnimation:(MPTableViewRowAnimation)animation withInsertSection:(MPTableViewSection *)insertSection withLastInsertionOriginY:(CGFloat)updateLastInsertionOriginY;
- (void)_updateMoveSectionViewToSection:(NSInteger)section fromLastSection:(NSInteger)lastSection withType:(MPSectionViewType)type withLastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance;
- (void)_updateAdjustSectionViewFromSection:(NSInteger)lastSection toSection:(NSInteger)section withType:(MPSectionViewType)type withLastHeight:(CGFloat)lastHeight withOffset:(CGFloat)offset;

@end

#pragma mark -

@interface MPTableViewUpdateManager : MPTableViewUpdateBase
@property (nonatomic, weak, readonly) MPTableView *tableView;
@property (nonatomic, weak) NSMutableArray *sectionsArray;

@property (nonatomic, strong) NSMutableArray *transactions;

@property (nonatomic) NSInteger dragFromSection;
@property (nonatomic) NSInteger dragToSection; // for optimization

+ (MPTableViewUpdateManager *)managerForTableView:(MPTableView *)tableView andSectionsArray:(NSMutableArray *)sectionsArray;
- (void)reset;
- (BOOL)hasUpdateNodes;

- (BOOL)addDeleteSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutSection:(NSInteger)section;
- (BOOL)addMoveInSection:(NSInteger)section withLastSection:(NSInteger)lastSection;

- (BOOL)addDeleteIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutIndexPath:(NSIndexPath *)indexPath;
- (BOOL)addMoveInIndexPath:(NSIndexPath *)indexPath withLastIndexPath:(NSIndexPath *)lastIndexPath withLastFrame:(CGRect)lastFrame;

- (CGFloat)update;

@end

#pragma mark -

@interface MPTableViewUpdatePart : MPTableViewUpdateBase

- (BOOL)addDeleteRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutRow:(NSInteger)row;
- (BOOL)addMoveInRow:(NSInteger)row withLastIndexPath:(NSIndexPath *)lastIndexPath withLastFrame:(CGRect)lastFrame;

@end

#pragma mark -

@interface MPTableView (MPTableView_EstimatedPrivate)

// estimated mode layout
- (BOOL)_isEstimatedMode;
- (BOOL)_hasEstimatedHeightForRow;
- (BOOL)_hasEstimatedHeightForHeader;
- (BOOL)_hasEstimatedHeightForFooter;

- (BOOL)_hasDisplayedSection:(MPTableViewSection *)section;

- (CGFloat)_estimatedGetSectionViewHeightWithType:(MPSectionViewType)type inSection:(MPTableViewSection *)section;
- (CGFloat)_estimatedDisplayCellInSection:(NSInteger)section atRow:(NSInteger)row withOffset:(CGFloat)offset needToLoadHeight:(BOOL *)needToLoadHeight;
- (void)_estimatedDisplaySectionViewInSection:(NSInteger)section withType:(MPSectionViewType)type;

@end

#pragma mark -

@interface MPTableViewSection : MPTableViewPosition
@property (nonatomic) NSInteger section;
@property (nonatomic) CGFloat headerHeight;
@property (nonatomic) CGFloat footerHeight;
@property (nonatomic) NSInteger numberOfRows;

@property (nonatomic, strong) MPTableViewUpdatePart *updatePart;

@property (nonatomic) CGFloat moveOutHeight; // backup for update

+ (instancetype)section;
- (void)reset;

- (void)addRowPosition:(CGFloat)position;
- (CGFloat)startPositionAtRow:(NSInteger)row;
- (CGFloat)endPositionAtRow:(NSInteger)row;
- (CGFloat)heightAtRow:(NSInteger)row;
- (NSInteger)rowAtContentOffsetY:(CGFloat)contentOffsetY; // includes header or footer

- (void)makeOffset:(CGFloat)offset;

- (void)rebuildForTableView:(MPTableView *)tableView withLastSection:(NSInteger)lastSection withDistance:(CGFloat)distance isMovement:(BOOL)isMovement;

- (CGFloat)updateWithPartForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay;
- (CGFloat)updateForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay;

- (CGFloat)estimateForTableView:(MPTableView *)tableView atFirstRow:(NSInteger)firstRow withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay;

@end
