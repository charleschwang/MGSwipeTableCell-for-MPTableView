//
//  MPTableView.m
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableView.h"
#import "MPTableViewSection.h"

//
//static NSRange
//MPSubtractionRange(NSRange subtrahend, NSRange minuend) {
//    if (subtrahend.length == minuend.length) {
//        return NSMakeRange(0, 0);
//    } else if (minuend.length == 0) {
//        return subtrahend;
//    } else {
//        return NSMakeRange((subtrahend.location == minuend.location) ? NSMaxRange(minuend) - 1: subtrahend.location, subtrahend.length - minuend.length + 1);
//    }
//}
//
//NS_INLINE BOOL
//_outofRange(NSUInteger target, NSRange range) {
//    return (target < range.location || target > range.location + range.length - 1) || range.length < 1;
//}

static MPIndexPathStruct MPIndexPathStructMake(NSInteger section, NSInteger row) {
    MPIndexPathStruct indexPath;
    indexPath.section = section;
    indexPath.row = row;
    return indexPath;
}

NS_INLINE BOOL MPEqualIndexPaths(MPIndexPathStruct indexPath1, MPIndexPathStruct indexPath2) {
    return indexPath1.section == indexPath2.section && indexPath2.row == indexPath1.row;
}

static NSComparisonResult MPCompareIndexPath(MPIndexPathStruct first, MPIndexPathStruct second) {
    if (first.section > second.section) {
        return NSOrderedDescending;
    } else if (first.section < second.section) {
        return NSOrderedAscending;
    } else {
        if (first.row > second.row) {
            return NSOrderedDescending;
        } else if (first.row < second.row) {
            return NSOrderedAscending;
        } else {
            return NSOrderedSame;
        }
    }
}

@implementation MPIndexPath (MPTableView)

+ (MPIndexPath *)indexPathForRow:(NSInteger)row inSection:(NSInteger)section {
    NSInteger indexes[2] = {section, row};
    MPIndexPath *indexPath = [MPIndexPath indexPathWithIndexes:indexes length:2];
    return indexPath;
}

- (NSInteger)section {
    NSParameterAssert(_length == 2);
    
    return _indexes[0];
}

- (NSInteger)row {
    NSParameterAssert(_length == 2);
    
    return _indexes[1];
}

- (void)setSection:(NSInteger)section {
    _indexes[0] = section;
}

- (void)setRow:(NSInteger)row {
    _indexes[1] = row;
}

- (MPIndexPathStruct)structIndexPath {
    MPIndexPathStruct result;
    result.section = self.section;
    result.row = self.row;
    return result;
}

- (NSComparisonResult)compareIndexPathAt:(MPIndexPathStruct)indexPath {
    return MPCompareIndexPath([self structIndexPath], indexPath);
}

- (NSComparisonResult)compareRowSection:(MPIndexPath *)indexPath {
    return MPCompareIndexPath([self structIndexPath], [indexPath structIndexPath]);
}

+ (MPIndexPath *)indexPathFromStruct:(MPIndexPathStruct)indexPath {
    return [MPIndexPath indexPathForRow:indexPath.row inSection:indexPath.section];
}

@end

#pragma mark -

@interface MPTableView (MPTableView_PanPrivate)

- (BOOL)mp_gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;

@end

@interface MPTableViewLongGestureRecognizer : UILongPressGestureRecognizer<UIGestureRecognizerDelegate>

@property (nonatomic, weak) MPTableView *tableView;

@end

@implementation MPTableViewLongGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action {
    if (self = [super initWithTarget:target action:action]) {
        self.cancelsTouchesInView = YES;
        self.delaysTouchesBegan = NO;
        self.delaysTouchesEnded = YES;
        self.allowableMovement = 0;
        self.minimumPressDuration = 0.1;
        self.delegate = self;
    }
    
    return self;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return [self.tableView mp_gestureRecognizerShouldBegin:gestureRecognizer];
}

@end

#pragma mark -

@interface MPTableReusableView (MPTableReusableView_internal)

@property (nonatomic, copy, readwrite) NSString *reuseIdentifier;

@end

#pragma mark -

static MPTableViewRowAnimation
MPTableViewGetRandomRowAnimation() {
    u_int32_t random = arc4random() % 7;
    return (MPTableViewRowAnimation)random;
}

static CGRect
MPTableViewDisappearViewFrameWithRowAnimation(UIView *view, CGFloat top, MPTableViewRowAnimation animation, MPTableViewPosition *sectionPosition) {
    CGRect frame = view.frame;
    switch (animation) {
        case MPTableViewRowAnimationFade: {
            if (view.opaque == NO) {
                view.hidden = YES;
                return frame;
            } else {
                frame.origin.y = top;
                view.alpha = 0;
            }
        }
            break;
        case MPTableViewRowAnimationRight: {
            frame.origin.y = top;
            frame.origin.x = frame.size.width;
            view.alpha = 0;
        }
            break;
        case MPTableViewRowAnimationLeft: {
            frame.origin.y = top;
            frame.origin.x = -frame.size.width;
            view.alpha = 0;
        }
            break;
        case MPTableViewRowAnimationTop: {
            frame.origin.y = top;
            frame.size.height = 0;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = bounds.size.height;
            view.bounds = bounds;
        }
            break;
        case MPTableViewRowAnimationBottom: {
            frame.origin.y = top;
            frame.size.height = 0;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = -bounds.size.height;
            view.bounds = bounds;
        }
            break;
        case MPTableViewRowAnimationMiddle: {
            if (sectionPosition) {
                frame.origin.y = top + (sectionPosition.endPos - sectionPosition.beginPos) / 2;
            } else {
                frame.origin.y = top;
            }
            frame.size.height = 0;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = bounds.size.height / 2;
            bounds.size.height = 0;
            view.bounds = bounds;
            
            view.alpha = 0;
        }
            break;
        case MPTableViewRowAnimationNone: {
            view.hidden = YES;
            return frame;
        }
            break;
            
        default:
            break;
    }
    
    return frame;
}

static void
MPTableViewDisplayViewFrameWithRowAnimation(UIView *view, CGRect originFrame, MPTableViewRowAnimation animation, MPTableViewPosition *sectionPosition) {
    CGRect frame = view.frame;
    switch (animation) {
        case MPTableViewRowAnimationFade: {
            if (view.opaque == NO) {
                view.hidden = NO;
                return;
            } else {
                frame.origin.y = originFrame.origin.y;
                view.alpha = 1;
            }
        }
            break;
        case MPTableViewRowAnimationRight: {
            frame.origin = originFrame.origin;
            view.alpha = 1;
        }
            break;
        case MPTableViewRowAnimationLeft: {
            frame.origin = originFrame.origin;
            view.alpha = 1;
        }
            break;
        case MPTableViewRowAnimationTop: {
            frame.origin.y = originFrame.origin.y;
            frame.size.height = originFrame.size.height;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = 0;
            view.bounds = bounds;
        }
            break;
        case MPTableViewRowAnimationBottom: {
            frame.origin.y = originFrame.origin.y;
            frame.size.height = originFrame.size.height;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = 0;
            view.bounds = bounds;
        }
            break;
        case MPTableViewRowAnimationMiddle: {
            frame.origin.y = originFrame.origin.y;
            frame.size.height = originFrame.size.height;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = 0;
            bounds.size.height = originFrame.size.height;
            view.bounds = bounds;
            
            view.alpha = 1;
        }
            break;
        case MPTableViewRowAnimationNone: {
            view.hidden = NO;
            return;
        }
            break;
            
        default:
            break;
    }
    
    view.frame = frame;
}

NSString *const MPTableViewSelectionDidChangeNotification = @"MPTableViewSelectionDidChangeNotification";

#define MPTableView_ReloadAsync_Exception if (!_mpDataSource) { \
    return MPTableViewMaxSize; \
}

#define MPTableView_Offscreen (frame.size.height <= 0 || frame.origin.y > _contentOffset.endPos || CGRectGetMaxY(frame) < _contentOffset.beginPos)
#define MPTableView_Onscreen (frame.size.height > 0 && frame.origin.y <= _contentOffset.endPos && CGRectGetMaxY(frame) >= _contentOffset.beginPos)

const CGFloat MPTableViewDefaultAnimationDuration = 0.3;

@implementation MPTableView {
    UIView *_contentWrapperView;
    MPTableViewPosition *_contentDrawArea; // area between header and footer
    MPTableViewPosition *_contentOffset;
    MPTableViewPosition *_currDrawArea; // should be content-offset minus the _contentDrawArea.beginPos
    
    MPIndexPathStruct _beginIndexPath, _endIndexPath;
    
    NSMutableSet *_selectedIndexPaths;
    MPIndexPath *_highlightedIndexPath;
    
    BOOL _layoutSubviewsLock;
    
    BOOL _needPreparationDetected;
    NSInteger _currSuspendHeaderSection, _currSuspendFooterSection; //
    
    NSUInteger _numberOfSections;
    
    NSMutableDictionary *_displayedCellsDic, *_displayedSectionViewsDic; //
    NSMutableArray *_sectionsAreaList;
    NSMutableDictionary *_reusableCellsDic, *_registerCellsClassDic, *_registerCellsNibDic; //
    NSMutableDictionary *_reusableReusableViewsDic, *_registerReusableViewsClassDic, *_registerReusableViewsNibDic;
    
    __weak id <MPTableViewDelegate> _mpDelegate;
    __weak id <MPTableViewDataSource> _mpDataSource;
    BOOL _reloadDataNeededFlag; // changed a datasource will set it to YES
    BOOL _reloadDataLayoutNeededFlag;
    
    //
    MPTableViewEstimatedManager *_estimatedUpdateManager;
    NSMutableDictionary *_estimatedCellsDic, *_estimatedSectionViewsDic;
    
    //
    NSMutableArray *_updateManagerStack;
    BOOL _updateDataPreparing;
    NSInteger _updateContextStep;
    
    //BOOL _updateTranslationalOptimization; // private, default is NO. Appropriately reducing the moving distance of views.
    NSUInteger _updateAnimationStep;
    
    CGFloat __updateInsertOriginTopPosition, __updateDeleteOriginTopPosition; //
    
    NSMutableDictionary *_insertCellsDic, *_insertSectionViewsDic;
    NSInteger _lastSuspendHeaderSection, _lastSuspendFooterSection;
    
    NSMutableDictionary *_deleteCellsDic, *_deleteSectionViewsDic;
    
    NSMutableArray *_updateAnimationBlocks;
    NSMutableSet *_updateExchangedOffscreenIndexPaths, *_updateExchangedSelectedIndexPaths;
    
    // for keeping animations natural when content offset has been changed in updating.
    NSMutableArray *_ignoredUpdateActions;
    BOOL _contentOffsetChanged;
    //
    BOOL _moveModeEnabled;
    CGPoint _movingMinuendPoint;
    CGFloat _movingScrollFate, _movingDistanceToOffset;
    MPTableViewLongGestureRecognizer *_movingLongGestureRecognizer;
    MPIndexPath *_movingIndexPath, *_sourceIndexPath;
    MPTableViewCell *_movingDraggedCell;
    CADisplayLink *_movingScrollDisplayLink;
    
    //
    CGFloat _previousContentOffset;
    NSMutableArray *_prefetchIndexPaths;
    
    //
    BOOL
    _respond_numberOfSectionsInMPTableView,
    
    _respond_heightForRowAtIndexPath,
    _respond_heightForHeaderInSection,
    _respond_heightForFooterInSection,
    
    _respond_estimatedHeightForRowAtIndexPath,
    _respond_estimatedHeightForHeaderInSection,
    _respond_estimatedHeightForFooterInSection,
    
    _respond_viewForHeaderInSection,
    _respond_viewForFooterInSection,
    
    _respond_canMoveRowAtIndexPath,
    _respond_canMoveRowToIndexPath,
    
    _respond_rectForCellToMoveRowAtIndexPath,
    
    _respond_moveRowAtIndexPathToIndexPath;
    
    BOOL
    _respond_willDisplayCellForRowAtIndexPath,
    _respond_willDisplayFooterViewForSection,
    _respond_willDisplayHeaderViewForSection,
    _respond_didEndDisplayingCellForRowAtIndexPath,
    _respond_didEndDisplayingFooterViewForSection,
    _respond_didEndDisplayingHeaderViewForSection,
    
    _respond_willSelectRowForCellAtIndexPath,
    _respond_willDeselectRowAtIndexPath,
    _respond_didSelectRowForCellAtIndexPath,
    _respond_didDeselectRowAtIndexPath,
    
    _respond_shouldHighlightRowAtIndexPath,
    _respond_didHighlightRowAtIndexPath,
    _respond_didUnhighlightRowAtIndexPath,
    
    _respond_beginToInsertCellForRowAtIndexPath,
    _respond_beginToDeleteCellForRowAtIndexPath,
    
    _respond_beginToInsertHeaderViewForSection,
    _respond_beginToInsertFooterViewForSection,
    _respond_beginToDeleteHeaderViewForSection,
    _respond_beginToDeleteFooterViewForSection,
    
    _respond_shouldMoveRowAtIndexPath,
    _respond_didEndMoveRowAtIndexPathToIndexPath;
    
    BOOL
    _respond_prefetchRowsAtIndexPaths,
    _respond_cancelPrefetchingForRowsAtIndexPaths;
}

@dynamic delegate;

#pragma mark -

- (instancetype)initWithFrame:(CGRect)frame style:(MPTableViewStyle)style {
    if (self = [super initWithFrame:frame]) {
        _style = style;
        [self _initializeWithoutCoder];
        [self _initializeData];
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame style:MPTableViewStylePlain];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        _style = (MPTableViewStyle)[aDecoder decodeIntegerForKey:@"_tableViewStyle"];
        _rowHeight = [aDecoder decodeDoubleForKey:@"_rowHeight"];
        _sectionHeaderHeight = [aDecoder decodeDoubleForKey:@"_sectionHeaderHeight"];
        _sectionFooterHeight = [aDecoder decodeDoubleForKey:@"_sectionFooterHeight"];
        _cachesReloadEnabled = [aDecoder decodeBoolForKey:@"_cachesReloadEnabled"];
        _needPreparationDetected = [aDecoder decodeBoolForKey:@"_needPreparationDetected"];
        _allowsSelection = [aDecoder decodeBoolForKey:@"_allowsSelection"];
        _allowsMultipleSelection = [aDecoder decodeBoolForKey:@"_allowsMultipleSelection"];
        _updateForceReload = [aDecoder decodeBoolForKey:@"_updateForceReload"];
        _updateLayoutSubviewsOptionEnabled = [aDecoder decodeBoolForKey:@"_updateLayoutSubviewsOptionEnabled"];
        _moveModeEnabled = [aDecoder decodeBoolForKey:@"_moveModeEnabled"];
        _allowsSelectionDuringMoving = [aDecoder decodeBoolForKey:@"_allowsSelectionDuringMoving"];
        _allowsDragCellOut = [aDecoder decodeBoolForKey:@"_allowsDragCellOut"];
        
        _registerCellsNibDic = [aDecoder decodeObjectForKey:@"_registerCellsNibDic"];
        _registerReusableViewsNibDic = [aDecoder decodeObjectForKey:@"_registerReusableViewsNibDic"];
        
        [self _initializeData];
        
        self.tableHeaderView = [aDecoder decodeObjectForKey:@"_tableHeaderView"];
        self.tableFooterView = [aDecoder decodeObjectForKey:@"_tableFooterView"];
        self.backgroundView = [aDecoder decodeObjectForKey:@"_backgroundView"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    if (![NSThread isMainThread]) {
        return [self performSelectorOnMainThread:@selector(encodeWithCoder:) withObject:aCoder waitUntilDone:YES];
    }
    
    [self _endMovingCellIfNeeded];
    
    [aCoder encodeInteger:_style forKey:@"_tableViewStyle"];
    [aCoder encodeDouble:_rowHeight forKey:@"_rowHeight"];
    [aCoder encodeDouble:_sectionHeaderHeight forKey:@"_sectionHeaderHeight"];
    [aCoder encodeDouble:_sectionFooterHeight forKey:@"_sectionFooterHeight"];
    [aCoder encodeBool:_cachesReloadEnabled forKey:@"_cachesReloadEnabled"];
    [aCoder encodeBool:_needPreparationDetected forKey:@"_needPreparationDetected"];
    [aCoder encodeBool:_allowsSelection forKey:@"_allowsSelection"];
    [aCoder encodeBool:_allowsMultipleSelection forKey:@"_allowsMultipleSelection"];
    [aCoder encodeBool:_updateForceReload forKey:@"_updateForceReload"];
    [aCoder encodeBool:_updateLayoutSubviewsOptionEnabled forKey:@"_updateLayoutSubviewsOptionEnabled"];
    [aCoder encodeBool:_moveModeEnabled forKey:@"_moveModeEnabled"];
    [aCoder encodeBool:_allowsSelectionDuringMoving forKey:@"_allowsSelectionDuringMoving"];
    [aCoder encodeBool:_allowsDragCellOut forKey:@"_allowsDragCellOut"];
    
    [aCoder encodeObject:_registerCellsNibDic forKey:@"_registerCellsNibDic"];
    [aCoder encodeObject:_registerReusableViewsNibDic forKey:@"_registerReusableViewsNibDic"];
    
    [_tableHeaderView removeFromSuperview];
    [_tableFooterView removeFromSuperview];
    [_contentWrapperView removeFromSuperview];
    [_backgroundView removeFromSuperview];
    
    NSMutableArray *sectionViews = [NSMutableArray arrayWithArray:_displayedSectionViewsDic.allValues];
    for (NSArray *array in _reusableReusableViewsDic.allValues) {
        [sectionViews addObjectsFromArray:array];
    }
    [sectionViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    [super encodeWithCoder:aCoder]; //
    
    [self addSubview:_contentWrapperView];
    [self sendSubviewToBack:_contentWrapperView];
    
    for (UIView *sectionView in sectionViews) {
        [self insertSubview:sectionView aboveSubview:_contentWrapperView];
    }
    [sectionViews removeAllObjects];
    
    if (_tableHeaderView) {
        [aCoder encodeObject:_tableHeaderView forKey:@"_tableHeaderView"];
        [self insertSubview:_tableHeaderView aboveSubview:_contentWrapperView];
    }
    if (_tableFooterView) {
        [aCoder encodeObject:_tableFooterView forKey:@"_tableFooterView"];
        [self insertSubview:_tableFooterView aboveSubview:_contentWrapperView];
    }
    if (_backgroundView) {
        [aCoder encodeObject:_backgroundView forKey:@"_backgroundView"];
        [self _layoutBackgroundViewIfNeeded];
    }
}

- (void)_initializeWithoutCoder {
    self.alwaysBounceVertical = YES;
    self.showsHorizontalScrollIndicator = NO;
    self.backgroundColor = [UIColor whiteColor];
    
    _rowHeight = MPTableViewDefaultCellHeight;
    if (self.style == MPTableViewStylePlain) {
        _sectionHeaderHeight = 0;
        _sectionFooterHeight = 0;
    } else {
        _sectionHeaderHeight = 35.;
        _sectionFooterHeight = 35.;
    }
    
    _allowsSelection = YES;
    _allowsMultipleSelection = NO;
    _cachesReloadEnabled = YES;
    _updateForceReload = YES;
    _updateLayoutSubviewsOptionEnabled = YES;
    _moveModeEnabled = NO;
    _allowsSelectionDuringMoving = NO;
    _allowsDragCellOut = NO;
}

- (void)_initializeData {
    
    [self _lockLayoutSubviews];
    
    [self addSubview:_contentWrapperView = [[UIView alloc] init]];
    [self sendSubviewToBack:_contentWrapperView];
    _contentWrapperView.autoresizesSubviews = NO; // @optional
    _numberOfSections = 1;
    
    [self _resetContentIndexPaths];
    _contentDrawArea = [MPTableViewPosition positionWithBegin:0 toEnd:0];
    _contentOffset = [MPTableViewPosition positionWithBegin:0 toEnd:0];
    _currDrawArea = [MPTableViewPosition positionWithBegin:0 toEnd:0];
    
    _displayedCellsDic = [[NSMutableDictionary alloc] init];
    _displayedSectionViewsDic = [[NSMutableDictionary alloc] init];
    _reusableCellsDic = [[NSMutableDictionary alloc] init];
    _reusableReusableViewsDic = [[NSMutableDictionary alloc] init];
    
    _sectionsAreaList = [[NSMutableArray alloc] init];
    
    _selectedIndexPaths = [[NSMutableSet alloc] init];
    
    _reloadDataNeededFlag = NO;
    _reloadDataLayoutNeededFlag = NO;
    
    _updateContextStep = 0;
    _updateAnimationStep = 0;
    _updateDataPreparing = NO;
    _contentOffsetChanged = NO;
}

- (void)_resetContentIndexPaths {
    _currSuspendFooterSection = _currSuspendHeaderSection = NSNotFound;
    
    _beginIndexPath = MPIndexPathStructMake(NSIntegerMax, MPSectionTypeFooter);
    _endIndexPath = MPIndexPathStructMake(NSIntegerMin, MPSectionTypeHeader);
    
    _highlightedIndexPath = nil;
}

- (void)dealloc {
    _cachesReloadEnabled = NO;
    [self _clear];
    [_sectionsAreaList removeAllObjects];
}

#pragma mark -

- (void)_respondsToDataSource {
    _respond_numberOfSectionsInMPTableView = [_mpDataSource respondsToSelector:@selector(numberOfSectionsInMPTableView:)];
    if (!_respond_numberOfSectionsInMPTableView && _mpDataSource) {
        _numberOfSections = 1;
    }
    
    _respond_heightForRowAtIndexPath = [_mpDataSource respondsToSelector:@selector(MPTableView:heightForRowAtIndexPath:)];
    _respond_heightForHeaderInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:heightForHeaderInSection:)];
    _respond_heightForFooterInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:heightForFooterInSection:)];
    
    _respond_estimatedHeightForRowAtIndexPath = [_mpDataSource respondsToSelector:@selector(MPTableView:estimatedHeightForRowAtIndexPath:)];
    _respond_estimatedHeightForHeaderInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:estimatedHeightForHeaderInSection:)];
    _respond_estimatedHeightForFooterInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:estimatedHeightForFooterInSection:)];
    
    _respond_viewForHeaderInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:viewForHeaderInSection:)];
    _respond_viewForFooterInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:viewForFooterInSection:)];
    
    _respond_canMoveRowAtIndexPath = [_mpDataSource respondsToSelector:@selector(MPTableView:canMoveRowAtIndexPath:)];
    _respond_canMoveRowToIndexPath = [_mpDataSource respondsToSelector:@selector(MPTableView:canMoveRowToIndexPath:)];
    _respond_rectForCellToMoveRowAtIndexPath = [_mpDataSource respondsToSelector:@selector(MPTableView:rectForCellToMoveRowAtIndexPath:)];
    _respond_moveRowAtIndexPathToIndexPath = [_mpDataSource respondsToSelector:@selector(MPTableView:moveRowAtIndexPath:toIndexPath:)];
}

- (void)_respondsToDelegate {
    _respond_willDisplayCellForRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:willDisplayCell:forRowAtIndexPath:)];
    _respond_willDisplayFooterViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:willDisplayFooterView:forSection:)];
    _respond_willDisplayHeaderViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:willDisplayHeaderView:forSection:)];

    _respond_didEndDisplayingCellForRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didEndDisplayingCell:forRowAtIndexPath:)];
    _respond_didEndDisplayingFooterViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:didEndDisplayingFooterView:forSection:)];
    _respond_didEndDisplayingHeaderViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:didEndDisplayingHeaderView:forSection:)];
    
    _respond_willSelectRowForCellAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:willSelectRowForCell:atIndexPath:)];
    _respond_willDeselectRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:willDeselectRowAtIndexPath:)];
    _respond_didSelectRowForCellAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didSelectRowForCell:atIndexPath:)];
    _respond_didDeselectRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didDeselectRowAtIndexPath:)];
    _respond_shouldHighlightRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:shouldHighlightRowAtIndexPath:)];
    _respond_didHighlightRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didHighlightRowAtIndexPath:)];
    _respond_didUnhighlightRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didUnhighlightRowAtIndexPath:)];
    
    _respond_beginToInsertCellForRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToInsertCell:forRowAtIndexPath:withAnimationPathPosition:)];
    _respond_beginToInsertHeaderViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToInsertHeaderView:forSection:withAnimationPathPosition:)];
    _respond_beginToInsertFooterViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToInsertFooterView:forSection:withAnimationPathPosition:)];
    
    _respond_beginToDeleteCellForRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToDeleteCell:forRowAtIndexPath:withAnimationPathPosition:)];
    _respond_beginToDeleteHeaderViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToDeleteHeaderView:forSection:withAnimationPathPosition:)];
    _respond_beginToDeleteFooterViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToDeleteFooterView:forSection:withAnimationPathPosition:)];
    
    _respond_shouldMoveRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:shouldMoveRowAtIndexPath:)];
    _respond_didEndMoveRowAtIndexPathToIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didEndMoveRowAtIndexPath:toIndexPath:)];
}

- (void)_respondsToPrefetchDataSource {
    _respond_prefetchRowsAtIndexPaths = [_prefetchDataSource respondsToSelector:@selector(MPTableView:prefetchRowsAtIndexPaths:)];
    _respond_cancelPrefetchingForRowsAtIndexPaths = [_prefetchDataSource respondsToSelector:@selector(MPTableView:cancelPrefetchingForRowsAtIndexPaths:)];
}

#pragma mark - public-

- (void)setDataSource:(id<MPTableViewDataSource>)dataSource {
    if (dataSource) {
        NSParameterAssert(![self isUpdating]);
        
        if (![dataSource respondsToSelector:@selector(MPTableView:cellForRowAtIndexPath:)] || ![dataSource respondsToSelector:@selector(MPTableView:numberOfRowsInSection:)]) {
            NSAssert(NO, @"dataSource @required");
            return;
        }
    }
    
    _mpDataSource = dataSource;
    [self _respondsToDataSource];
    
    [self _unlockLayoutSubviews];
    _reloadDataNeededFlag = YES;
    _reloadDataLayoutNeededFlag = YES;
    [self setNeedsLayout];
}

- (id<MPTableViewDataSource>)dataSource {
    return _mpDataSource;
}

- (void)setDelegate:(id<MPTableViewDelegate>)delegate {
    if (delegate) {
        NSParameterAssert(![self isUpdating]);
    }
    _mpDelegate = delegate;
    
    [super setDelegate:delegate];
    [self _respondsToDelegate];
}

- (id<MPTableViewDelegate>)delegate {
    return _mpDelegate;
}

- (void)setPrefetchDataSource:(id<MPTableViewDataSourcePrefetching>)prefetchDataSource {
    _prefetchDataSource = prefetchDataSource;
    [self _respondsToPrefetchDataSource];
    if (_prefetchDataSource && !_prefetchIndexPaths) {
        _prefetchIndexPaths = [[NSMutableArray alloc] init];
    }
}

- (void)setContentOffset:(CGPoint)contentOffset {
    [super setContentOffset:contentOffset];
    [self _layoutBackgroundViewIfNeeded];
}

- (void)setContentSize:(CGSize)contentSize {
    if (!CGSizeEqualToSize(contentSize, _contentWrapperView.frame.size)) {
        _contentWrapperView.frame = CGRectMake(0, 0, contentSize.width, contentSize.height);
    }
    
    [super setContentSize:contentSize];
}

NS_INLINE CGRect _MP_SetViewWidth(UIView *view, CGFloat width) {
    CGRect frame = view.frame;
    if (frame.size.width != width) {
        frame.size.width = width;
        view.frame = frame;
    }
    return frame;
}

static void _UIFrameWithoutAnimation(UIView *view, CGRect frame) {
    [UIView performWithoutAnimation:^{
        view.frame = frame;
    }];
}

- (void)setFrame:(CGRect)frame {
    CGRect selfFrame = [super frame];
    if (CGRectEqualToRect(selfFrame, frame)) {
        return;
    }
    
    [super setFrame:frame];
    
    if (selfFrame.size.width != frame.size.width) {
        [self _setSubviewsWidth:frame.size.width];
    }
    
    [self _layoutBackgroundViewIfNeeded];
    [self layoutSubviews];
}

- (void)setBounds:(CGRect)bounds {
    CGRect selfBounds = [super bounds];
    if (CGRectEqualToRect(selfBounds, bounds)) {
        return;
    }
    
    [super setBounds:bounds];
    
    if (selfBounds.size.width != bounds.size.width) {
        [self _setSubviewsWidth:bounds.size.width];
    }
    
    [self _layoutBackgroundViewIfNeeded];
    [self layoutSubviews];
}

- (void)_setSubviewsWidth:(CGFloat)width {
    _MP_SetViewWidth(self.tableHeaderView, width);
    _MP_SetViewWidth(self.tableFooterView, width);
    
    for (MPTableViewCell *cell in _displayedCellsDic.allValues) {
        _MP_SetViewWidth(cell, width);
    }
    for (UIView *sectionView in _displayedSectionViewsDic.allValues) {
        _MP_SetViewWidth(sectionView, width);
    }
    
    for (MPTableViewCell *cell in _insertCellsDic.allValues) {
        _MP_SetViewWidth(cell, width);
    }
    for (UIView *sectionView in _insertSectionViewsDic.allValues) {
        _MP_SetViewWidth(sectionView, width);
    }
    
    CGSize contentSize = self.contentSize;
    contentSize.width = width;
    self.contentSize = contentSize;
}

- (NSUInteger)numberOfSections {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    return _numberOfSections;
}

- (NSUInteger)numberOfRowsInSection:(NSUInteger)sectionIndex {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (sectionIndex >= _sectionsAreaList.count) {
        return NSNotFound;
    } else {
        MPTableViewSection *section = _sectionsAreaList[sectionIndex];
        return section.numberOfRows;
    }
}

- (void)setRowHeight:(CGFloat)rowHeight {
    NSParameterAssert(rowHeight >= 0);
    _rowHeight = rowHeight;
}

- (void)setSectionHeaderHeight:(CGFloat)sectionHeaderHeight {
    NSParameterAssert(sectionHeaderHeight >= 0);
    _sectionHeaderHeight = sectionHeaderHeight;
}

- (void)setSectionFooterHeight:(CGFloat)sectionFooterHeight {
    NSParameterAssert(sectionFooterHeight >= 0);
    _sectionFooterHeight = sectionFooterHeight;
}

- (void)setTableHeaderView:(UIView *)tableHeaderView {
    if (_tableHeaderView == tableHeaderView && [_tableHeaderView superview] == self) {
        return;
    }
    
    if ([_tableHeaderView superview] == self) {
        [_tableHeaderView removeFromSuperview];
    }
    _tableHeaderView = tableHeaderView;
    
    if (!_tableHeaderView) {
        return;
    }
    
    CGRect frame = _tableHeaderView.frame;
    frame.origin = CGPointZero;
    frame.size.width = self.bounds.size.width;
    _tableHeaderView.frame = frame;
    [self insertSubview:_tableHeaderView aboveSubview:_contentWrapperView];
    
    if (_contentDrawArea.beginPos == frame.size.height) {
        return;
    }
    CGFloat contentHeight = _contentDrawArea.endPos - _contentDrawArea.beginPos;
    _contentDrawArea.beginPos = frame.size.height;
    _contentDrawArea.endPos = _contentDrawArea.beginPos + contentHeight;
    
    [self setContentSize:CGSizeMake(self.bounds.size.width, _contentDrawArea.endPos + self.tableFooterView.frame.size.height)];
    
    if (contentHeight > 0) {
        [self _resetContentIndexPaths];
        [self _cacheDisplayingCells];
        [self _cacheDisplayingSectionViews];
        [self _getDisplayingArea];
        [self _updateDisplayingArea];
    }
}

- (void)setTableFooterView:(UIView *)tableFooterView {
    if (_tableFooterView == tableFooterView && [_tableFooterView superview] == self) {
        return;
    }
    
    if ([_tableFooterView superview] == self) {
        [_tableFooterView removeFromSuperview];
    }
    _tableFooterView = tableFooterView;
    
    if (!_tableFooterView) {
        return;
    }
    
    CGRect frame = _tableFooterView.frame;
    frame.origin = CGPointMake(0, _contentDrawArea.endPos);
    frame.size.width = self.bounds.size.width;
    _tableFooterView.frame = frame;
    [self insertSubview:_tableFooterView aboveSubview:_contentWrapperView];
    
    [self setContentSize:CGSizeMake(self.bounds.size.width, _contentDrawArea.endPos + frame.size.height)];
}

- (void)setBackgroundView:(UIView *)backgroundView {
    if (_backgroundView == backgroundView) {
        return;
    }
    
    [_backgroundView removeFromSuperview];
    _backgroundView = backgroundView;
    
    [self _layoutBackgroundViewIfNeeded];
}

- (void)_layoutBackgroundViewIfNeeded {
    if (!_backgroundView) {
        return;
    }
    
    CGRect frame = self.bounds;
    frame.origin.y = self.contentOffset.y;
    _UIFrameWithoutAnimation(_backgroundView, frame);
    
    if ([_backgroundView superview] != self) {
        [self insertSubview:_backgroundView belowSubview:_contentWrapperView];
    }
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
    _needPreparationDetected = (self.style == MPTableViewStylePlain) && (contentInset.top != 0 || contentInset.bottom != 0);
    [super setContentInset:contentInset];
    _previousContentOffset = self.contentOffset.y;
    
    [self layoutSubviews];
}

- (UIEdgeInsets)_contentInset {
#ifdef __IPHONE_11_0
    if (@available(iOS 11.0, *)) {
        return self.adjustedContentInset;
    } else {
        return self.contentInset;
    }
#else
    return self.contentInset;
#endif
}

- (MPTableViewCell *)cellForRowAtIndexPath:(MPIndexPath *)indexPath {
    NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
    
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    MPTableViewCell *result = nil;
    result = [_displayedCellsDic objectForKey:indexPath];
    return result;
}

- (MPTableReusableView *)sectionHeaderInSection:(NSUInteger)section {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    return [_displayedSectionViewsDic objectForKey:[MPIndexPath indexPathForRow:MPSectionTypeHeader inSection:section]];
}

- (MPTableReusableView *)sectionFooterInSection:(NSUInteger)section {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    return [_displayedSectionViewsDic objectForKey:[MPIndexPath indexPathForRow:MPSectionTypeFooter inSection:section]];
}

- (MPIndexPath *)indexPathForCell:(MPTableViewCell *)cell {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    MPIndexPath *result = nil;
    for (MPIndexPath *indexPath in _displayedCellsDic.allKeys) {
        MPTableViewCell *_cell = [_displayedCellsDic objectForKey:indexPath];
        if (_cell == cell) {
            result = [indexPath copy];
            break;
        }
    }
    
    return result;
}

- (NSArray *)visibleCells {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    return _displayedCellsDic.allValues;
}

- (NSArray *)indexPathsForVisibleRows {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    return _displayedCellsDic.allKeys;
}

- (NSArray *)visibleCellsInRect:(CGRect)rect {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    if (rect.origin.x > self.bounds.size.width || CGRectGetMaxX(rect) < 0 || rect.origin.y > _contentDrawArea.endPos || CGRectGetMaxY(rect) < _contentDrawArea.beginPos || rect.size.width <= 0 || rect.size.height <= 0) {
        return nil;
    }
    
    NSMutableArray *visibleCells = [[NSMutableArray alloc] init];
    
    for (MPTableViewCell *cell in _displayedCellsDic.allValues) {
        if (CGRectIntersectsRect(rect, cell.frame)) {
            [visibleCells addObject:cell];
        }
    }
    
    return visibleCells;
}

- (NSArray *)indexPathsForRowsInRect:(CGRect)rect {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    if (rect.origin.x > self.bounds.size.width || CGRectGetMaxX(rect) < 0 || rect.origin.y > _contentDrawArea.endPos || CGRectGetMaxY(rect) < _contentDrawArea.beginPos || rect.size.width <= 0 || rect.size.height <= 0) {
        return nil;
    }
    
    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
    MPIndexPath *beginIndexPath = [MPIndexPath indexPathFromStruct:[self _indexPathAtContentOffset:rect.origin.y - _contentDrawArea.beginPos]];
    MPIndexPath *endIndexPath = [MPIndexPath indexPathFromStruct:[self _indexPathAtContentOffset:CGRectGetMaxY(rect) - _contentDrawArea.beginPos]];
    
    for (NSInteger i = beginIndexPath.section; i <= endIndexPath.section; i++) {
        NSUInteger numberOfRows = [self numberOfRowsInSection:i];
        if (i == beginIndexPath.section) {
            NSInteger j = (beginIndexPath.row == MPSectionTypeHeader) ? 0 : beginIndexPath.row;
            if (beginIndexPath.section == endIndexPath.section) {
                if (endIndexPath.row == MPSectionTypeHeader) {
                    break;
                } else if (endIndexPath.row < MPSectionTypeFooter) {
                    numberOfRows = endIndexPath.row + 1;
                }
                for (; j < numberOfRows; j++) {
                    [indexPaths addObject:[MPIndexPath indexPathForRow:j inSection:i]];
                }
            } else {
                for (; j < numberOfRows; j++) {
                    [indexPaths addObject:[MPIndexPath indexPathForRow:j inSection:i]];
                }
            }
        } else {
            if (i == endIndexPath.section) {
                if (endIndexPath.row == MPSectionTypeHeader) {
                    numberOfRows = 0;
                } else if (endIndexPath.row < MPSectionTypeFooter) {
                    numberOfRows = endIndexPath.row + 1;
                }
            }
            for (NSInteger j = 0; j < numberOfRows; j++) {
                [indexPaths addObject:[MPIndexPath indexPathForRow:j inSection:i]];
            }
        }
    }
    
    return indexPaths;
}

- (NSArray *)indexPathsForRowsInSection:(NSUInteger)section {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    if (section >= _sectionsAreaList.count) {
        return nil;
    }
    
    MPTableViewSection *section_ = _sectionsAreaList[section];
    if (section_.numberOfRows == 0) {
        return nil;
    }
    
    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
    for (NSInteger i = 0; i < section_.numberOfRows; i++) {
        [indexPaths addObject:[MPIndexPath indexPathForRow:i inSection:section]];
    }
    
    return indexPaths;
}

- (MPIndexPath *)beginIndexPath {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    MPIndexPath *indexPath = [MPIndexPath indexPathFromStruct:_beginIndexPath];
    
    if (indexPath.row == MPSectionTypeHeader) {
        MPTableViewSection *section = _sectionsAreaList[indexPath.section];
        indexPath.row = section.numberOfRows ? 0 : NSNotFound;
    }
    
    if (indexPath.row == MPSectionTypeFooter) {
        indexPath.row = NSNotFound;
        while (indexPath.section + 1 < _endIndexPath.section) {
            indexPath.section++;
            MPTableViewSection *section = _sectionsAreaList[indexPath.section];
            if (section.numberOfRows > 0) {
                indexPath.row = 0;
                break;
            }
        }
    }
    
    return indexPath;
}

- (MPIndexPath *)endIndexPath {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    MPIndexPath *indexPath = [MPIndexPath indexPathFromStruct:_endIndexPath];
    
    if (indexPath.row == MPSectionTypeHeader) {
        indexPath.row = NSNotFound;
        while (indexPath.section > _beginIndexPath.section) {
            indexPath.section--;
            MPTableViewSection *section = _sectionsAreaList[indexPath.section];
            if (section.numberOfRows > 0) {
                indexPath.row = section.numberOfRows - 1;
                break;
            }
        }
    }
    
    if (indexPath.row == MPSectionTypeFooter) {
        MPTableViewSection *section = _sectionsAreaList[indexPath.section];
        indexPath.row = section.numberOfRows ? section.numberOfRows - 1 : NSNotFound;
    }
    
    return indexPath;
}

- (MPIndexPathStruct)__beginIndexPath {
    return _beginIndexPath;
}
- (MPIndexPathStruct)__endIndexPath {
    return _endIndexPath;
}

- (CGRect)rectForSection:(NSUInteger)section {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (section >= _sectionsAreaList.count) {
        return CGRectNull;
    }
    
    CGRect frame;
    MPTableViewSection *sectionObj = _sectionsAreaList[section];
    frame.origin = CGPointMake(0, _contentDrawArea.beginPos + sectionObj.beginPos);
    frame.size = CGSizeMake(self.bounds.size.width, sectionObj.endPos - sectionObj.beginPos);
    return frame;
}

- (CGRect)rectForHeaderInSection:(NSUInteger)section {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (section >= _sectionsAreaList.count) {
        return CGRectNull;
    }
    
    CGRect frame;
    MPTableViewSection *sectionObj = _sectionsAreaList[section];
    frame.origin = CGPointMake(0, _contentDrawArea.beginPos + sectionObj.beginPos);
    frame.size = CGSizeMake(self.bounds.size.width, sectionObj.headerHeight);
    return frame;
}

- (CGRect)rectForFooterInSection:(NSUInteger)section {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (section >= _sectionsAreaList.count) {
        return CGRectNull;
    }
    
    CGRect frame;
    MPTableViewSection *sectionObj = _sectionsAreaList[section];
    frame.origin = CGPointMake(0, _contentDrawArea.beginPos + sectionObj.beginPos);
    frame.size = CGSizeMake(self.bounds.size.width, sectionObj.footerHeight);
    return frame;
}

- (CGRect)rectForRowAtIndexPath:(MPIndexPath *)indexPath {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (indexPath.section < 0 || indexPath.section >= _sectionsAreaList.count) {
        return CGRectNull;
    }
    
    MPTableViewSection *section = _sectionsAreaList[indexPath.section];
    if (indexPath.row < 0 || indexPath.row >= section.numberOfRows) {
        return CGRectNull;
    }
    
    return [self _cellFrameAtIndexPath:indexPath];
}

- (MPIndexPath *)indexPathForRowAtPoint:(CGPoint)point {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (point.y < _contentDrawArea.beginPos || point.y > _contentDrawArea.endPos) {
        return nil;
    } else {
        MPIndexPath *indexPath = [MPIndexPath indexPathFromStruct:[self _indexPathAtContentOffset:(point.y - _contentDrawArea.beginPos)]];
        if (indexPath.row == MPSectionTypeHeader || indexPath.row == MPSectionTypeFooter) {
            return nil;
        } else {
            return indexPath;
        }
    }
}

- (NSUInteger)indexForSectionAtPoint:(CGPoint)point {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (point.y < _contentDrawArea.beginPos || point.y > _contentDrawArea.endPos) {
        return NSNotFound;
    } else {
        return [self _sectionIndexAtContentOffset:point.y - _contentDrawArea.beginPos];
    }
}

- (void)scrollToRowAtIndexPath:(MPIndexPath *)indexPath atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (scrollPosition == MPTableViewScrollPositionNone) {
        return;
    }
    
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
    NSAssert(indexPath.section < _sectionsAreaList.count, @"an non-existent section");
    
    MPTableViewSection *section = _sectionsAreaList[indexPath.section];
    NSAssert(indexPath.row < section.numberOfRows, @"row overflow");
    
    CGFloat _contentOffsetY = 0;
    switch (scrollPosition) {
        case MPTableViewScrollPositionTop: {
            _contentOffsetY = [section rowPositionBeginAt:indexPath.row] - [self _contentInset].top;
            if (_respond_viewForHeaderInSection && self.style == MPTableViewStylePlain) {
                _contentOffsetY -= section.headerHeight;
            }
        }
            break;
        case MPTableViewScrollPositionMiddle: {
            CGFloat cellBeginPos = [section rowPositionBeginAt:indexPath.row];
            CGFloat cellEndPos = [section rowPositionEndAt:indexPath.row];
            _contentOffsetY = cellBeginPos + (cellEndPos - cellBeginPos) / 2 - self.bounds.size.height / 2;
        }
            break;
        case MPTableViewScrollPositionBottom: {
            _contentOffsetY = [section rowPositionEndAt:indexPath.row] - self.bounds.size.height + [self _contentInset].bottom;
            if (_respond_viewForFooterInSection && self.style == MPTableViewStylePlain) {
                _contentOffsetY += section.footerHeight;
            }
        }
            break;
        default:
            return;
    }
    
    [self _setUsableContentOffsetY:_contentOffsetY animated:animated];
}

- (void)_setUsableContentOffsetY:(CGFloat)_contentOffsetY animated:(BOOL)animated {
    _contentOffsetY += _contentDrawArea.beginPos;
    if (_contentOffsetY + self.bounds.size.height > self.contentSize.height + [self _contentInset].bottom) {
        _contentOffsetY = self.contentSize.height + [self _contentInset].bottom - self.bounds.size.height;
    }
    if (_contentOffsetY < -[self _contentInset].top) {
        _contentOffsetY = -[self _contentInset].top;
    }
    
    [self setContentOffset:CGPointMake(0, _contentOffsetY) animated:animated];
}

- (void)scrollToHeaderAtSection:(NSUInteger)sectionIndex atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (scrollPosition == MPTableViewScrollPositionNone) {
        return;
    }
    
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    NSAssert(sectionIndex < _sectionsAreaList.count, @"an non-existent section");
    
    MPTableViewSection *section = _sectionsAreaList[sectionIndex];
    
    CGFloat _contentOffsetY = 0;
    switch (scrollPosition) {
        case MPTableViewScrollPositionTop: {
            _contentOffsetY = section.beginPos - [self _contentInset].top;
        }
            break;
        case MPTableViewScrollPositionMiddle: {
            CGFloat beginPos = section.beginPos;
            CGFloat endPos = section.beginPos + section.headerHeight;
            _contentOffsetY = beginPos + (endPos - beginPos) / 2 - self.bounds.size.height / 2;
        }
            break;
        case MPTableViewScrollPositionBottom: {
            _contentOffsetY = section.beginPos + section.headerHeight - self.bounds.size.height + [self _contentInset].bottom;
        }
            break;
        default:
            return;
    }
    
    [self _setUsableContentOffsetY:_contentOffsetY animated:animated];
}

- (void)scrollToFooterAtSection:(NSUInteger)sectionIndex atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (scrollPosition == MPTableViewScrollPositionNone) {
        return;
    }
    
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    NSAssert(sectionIndex < _sectionsAreaList.count, @"an non-existent section");
    
    MPTableViewSection *section = _sectionsAreaList[sectionIndex];
    
    CGFloat _contentOffsetY = 0;
    switch (scrollPosition) {
        case MPTableViewScrollPositionTop: {
            _contentOffsetY = section.endPos - section.footerHeight - [self _contentInset].top;
        }
            break;
        case MPTableViewScrollPositionMiddle: {
            CGFloat beginPos = section.endPos - section.footerHeight;
            CGFloat endPos = section.endPos;
            _contentOffsetY = beginPos + (endPos - beginPos) / 2 - self.bounds.size.height / 2;
        }
            break;
        case MPTableViewScrollPositionBottom: {
            _contentOffsetY = section.endPos - self.bounds.size.height + [self _contentInset].bottom;
        }
            break;
        default:
            return;
    }
    
    [self _setUsableContentOffsetY:_contentOffsetY animated:animated];
}

- (void)setAllowsMultipleSelection:(BOOL)allowsMultipleSelection {
    if (_allowsMultipleSelection == allowsMultipleSelection) {
        return;
    }
    for (MPIndexPath *indexPath in _selectedIndexPaths) {
        [self _deselectRowAtIndexPath:indexPath animated:NO selectedIndexPathRemove:NO];
    }
    [_selectedIndexPaths removeAllObjects];
    
    _allowsMultipleSelection = allowsMultipleSelection;
    if (_allowsMultipleSelection) {
        _allowsSelection = YES;
    }
}

- (MPIndexPath *)indexPathForSelectedRow {
    return [_selectedIndexPaths anyObject];
}

- (NSArray *)indexPathsForSelectedRows {
    return [_selectedIndexPaths allObjects];
}

- (void)selectRowAtIndexPath:(MPIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(MPTableViewScrollPosition)scrollPosition {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    
    if (_respond_willSelectRowForCellAtIndexPath) {
        MPIndexPath *newIndexPath = [_mpDelegate MPTableView:self willSelectRowForCell:cell atIndexPath:indexPath];
        if (!newIndexPath) {
            return;
        }
        if (![indexPath isEqual:newIndexPath]) {
            cell = [_displayedCellsDic objectForKey:indexPath = [newIndexPath copy]];
        }
    }
    [_selectedIndexPaths addObject:indexPath];
    
    if (cell) {
        [cell setSelected:YES animated:animated];
    }
    
    [self scrollToRowAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
    
    if (_respond_didSelectRowForCellAtIndexPath) {
        [_mpDelegate MPTableView:self didSelectRowForCell:cell atIndexPath:indexPath];
    }
}

- (void)scrollToNearestSelectedRowAtScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (scrollPosition == MPTableViewScrollPositionNone || !_selectedIndexPaths.count) {
        return;
    }
    
    MPIndexPath *nearestSelectedIndexPath = [MPIndexPath indexPathForRow:NSNotFound inSection:NSNotFound];
    for (MPIndexPath *indexPath in _selectedIndexPaths) {
        if ([indexPath compareRowSection:nearestSelectedIndexPath] == NSOrderedAscending) {
            nearestSelectedIndexPath = indexPath;
        }
    }
    if (nearestSelectedIndexPath.section < NSNotFound && nearestSelectedIndexPath.row < NSNotFound) {
        [self scrollToRowAtIndexPath:nearestSelectedIndexPath atScrollPosition:scrollPosition animated:animated];
    }
}

- (void)_deselectRowAtIndexPath:(MPIndexPath *)indexPath animated:(BOOL)animated selectedIndexPathRemove:(BOOL)remove {
    if (!indexPath) {
        return;
    }
    
    MPTableViewCell *selectedCell = [_displayedCellsDic objectForKey:indexPath];
    if (_respond_willDeselectRowAtIndexPath) {
        MPIndexPath *newIndexPath = [_mpDelegate MPTableView:self willDeselectRowAtIndexPath:indexPath];
        if (!newIndexPath) {
            return;
        }
        if (![newIndexPath isEqual:indexPath]) {
            selectedCell = [_displayedCellsDic objectForKey:indexPath = [newIndexPath copy]];
        }
    }
    if (selectedCell) {
        [selectedCell setSelected:NO animated:animated];
    }
    
    if (remove) {
        [_selectedIndexPaths removeObject:indexPath];
    }
    
    if (_respond_didDeselectRowAtIndexPath) {
        [_mpDelegate MPTableView:self didDeselectRowAtIndexPath:indexPath];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:MPTableViewSelectionDidChangeNotification object:self];
}

- (void)deselectRowAtIndexPath:(MPIndexPath *)indexPath animated:(BOOL)animated {
    if (![_selectedIndexPaths containsObject:indexPath]) {
        return;
    }
    [self _deselectRowAtIndexPath:indexPath animated:animated selectedIndexPathRemove:YES];
}

- (BOOL)isUpdating {
    return _updateAnimationStep != 0;
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    _updateDataPreparing = YES;
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx >= _numberOfSections) {
            MPTableViewThrowUpdateException(@"delete section is overflow");
        }
        if (![updateManager addDeleteSection:idx withAnimation:animation]) {
            MPTableViewThrowUpdateException(@"check duplicate indexPaths");
        }
    }];
    
    _updateDataPreparing = NO;
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut completion:nil];
    }
}

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    
    _updateDataPreparing = YES;
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    NSUInteger count;
    if (_respond_numberOfSectionsInMPTableView) {
        count = [_mpDataSource numberOfSectionsInMPTableView:self];
    } else {
        count = _numberOfSections;
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx >= count) {
            MPTableViewThrowUpdateException(@"insert section is overflow");
        }
        if (![updateManager addInsertSection:idx withAnimation:animation]) {
            MPTableViewThrowUpdateException(@"check duplicate indexPaths");
        }
    }];
    
    _updateDataPreparing = NO;
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut completion:nil];
    }
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    
    _updateDataPreparing = YES;
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx >= _numberOfSections) {
            MPTableViewThrowUpdateException(@"reload section is overflow");
        }
        if (![updateManager addReloadSection:idx withAnimation:animation]) {
            MPTableViewThrowUpdateException(@"check duplicate indexPaths");
        }
    }];
    
    _updateDataPreparing = NO;
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut completion:nil];
    }
}

- (void)moveSection:(NSUInteger)section toSection:(NSUInteger)newSection {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    
    _updateDataPreparing = YES;
    
    if (section == newSection) {
        MPTableViewThrowUpdateException(@"original section can not be equal to the new section");
    }
    if (section >= _numberOfSections) {
        MPTableViewThrowUpdateException(@"original section is overflow");
    }
    
    NSUInteger count;
    if (_respond_numberOfSectionsInMPTableView) {
        count = [_mpDataSource numberOfSectionsInMPTableView:self];
    } else {
        count = _numberOfSections;
    }
    
    if (newSection >= count) {
        MPTableViewThrowUpdateException(@"new section is overflow");
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    if (![updateManager addMoveOutSection:section]) {
        MPTableViewThrowUpdateException(@"check duplicate indexPaths");
    }
    
    if (![updateManager addMoveInSection:newSection withOriginIndex:section]) {
        MPTableViewThrowUpdateException(@"check duplicate indexPaths");
    }
    
    _updateDataPreparing = NO;
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut completion:nil];
    }
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    
    _updateDataPreparing = YES;
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    for (MPIndexPath *indexPath in indexPaths) {
        NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
        if (indexPath.section >= _numberOfSections) {
            MPTableViewThrowUpdateException(@"delete section is overflow");
        }
        if (indexPath.row >= [self numberOfRowsInSection:indexPath.section]) {
            MPTableViewThrowUpdateException(@"delete row is overflow");
        }
        
        if (![updateManager addDeleteIndexPath:indexPath withAnimation:animation]) {
            MPTableViewThrowUpdateException(@"check duplicate indexPaths");
        }
    }
    
    _updateDataPreparing = NO;
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut completion:nil];
    }
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    
    _updateDataPreparing = YES;
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    NSUInteger count;
    if (_respond_numberOfSectionsInMPTableView) {
        count = [_mpDataSource numberOfSectionsInMPTableView:self];
    } else {
        count = _numberOfSections;
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    for (MPIndexPath *indexPath in indexPaths) {
        NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
        if (indexPath.section >= count) {
            MPTableViewThrowUpdateException(@"insert section is overflow");
        }
        if (![updateManager addInsertIndexPath:indexPath withAnimation:animation]) {
            MPTableViewThrowUpdateException(@"check duplicate indexPaths");
        }
    }
    
    _updateDataPreparing = NO;
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut completion:nil];
    }
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    
    _updateDataPreparing = YES;
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    for (MPIndexPath *indexPath in indexPaths) {
        NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
        if (indexPath.section >= _numberOfSections) {
            MPTableViewThrowUpdateException(@"reload section is overflow");
        }
        if (indexPath.row >= [self numberOfRowsInSection:indexPath.section]) {
            MPTableViewThrowUpdateException(@"reload row is overflow");
        }
        
        if (![updateManager addReloadIndexPath:indexPath withAnimation:animation]) {
            MPTableViewThrowUpdateException(@"check duplicate indexPaths");
        }
    }
    
    _updateDataPreparing = NO;
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut completion:nil];
    }
}

- (void)moveRowAtIndexPath:(MPIndexPath *)indexPath toIndexPath:(MPIndexPath *)newIndexPath {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    
    _updateDataPreparing = YES;
    
    if ([indexPath compareRowSection:newIndexPath] == NSOrderedSame) {
        MPTableViewThrowUpdateException(@"original indexpath can not be equal to the new indexpath");
    }
    
    NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
    NSParameterAssert(newIndexPath.row >= 0 && newIndexPath.section >= 0);
    
    if (indexPath.section >= _numberOfSections) {
        MPTableViewThrowUpdateException(@"original section is overflow");
    }
    if (indexPath.row >= [self numberOfRowsInSection:indexPath.section]) {
        MPTableViewThrowUpdateException(@"original row is overflow");
    }
    
    NSUInteger count;
    if (_respond_numberOfSectionsInMPTableView) {
        count = [_mpDataSource numberOfSectionsInMPTableView:self];
    } else {
        count = _numberOfSections;
    }
    
    if (newIndexPath.section >= count) {
        MPTableViewThrowUpdateException(@"new section is overflow");
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    if (![updateManager addMoveOutIndexPath:indexPath]) {
        MPTableViewThrowUpdateException(@"check duplicate indexPaths");
    }
    
    if (![updateManager addMoveInIndexPath:newIndexPath withFrame:[self _cellFrameAtIndexPath:indexPath] withOriginIndexPath:indexPath]) {
        MPTableViewThrowUpdateException(@"check duplicate indexPaths");
    }
    
    _updateDataPreparing = NO;
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut completion:nil];
    }
}

- (BOOL)isUpdateForceReload {
    return _updateForceReload;
}

//- (void)beginUpdates {
//    NSParameterAssert(_mpDataSource);
//    NSParameterAssert(_movingIndexPath == nil);
//
//    if (_updateDataPreparing || _movingIndexPath || !_numberOfSections || _reloadDataNeededFlag) {
//        return;
//    }
//
//    _updateContextStep++;
//    [self _lockLayoutSubviews];
//}

// deprecated
//- (void)endUpdates {
//    NSParameterAssert(_mpDataSource);
//    NSParameterAssert(_movingIndexPath == nil);
//
//    if (_updateDataPreparing || _movingIndexPath || ![self _isLayoutSubviewsLock] || _reloadDataNeededFlag) {
//        return;
//    }
//
//    _updateContextStep--;
//    NSAssert(_updateContextStep >= 0, @"every invocation of -endUpdates must have a -beginUpdates invoking in front");
//
//    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
//    [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut completion:nil];
//}

- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion {
    [self performBatchUpdates:updates duration:MPTableViewDefaultAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut completion:completion];
}

- (void)performBatchUpdates:(void (^)(void))updates duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options completion:(void (^)(BOOL))completion {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath || !_numberOfSections || _reloadDataNeededFlag) {
        return;
    }
    
    _updateContextStep++;
    [self _lockLayoutSubviews];
    
    MPTableViewUpdateManager *updateManager;
    if (_updateContextStep > 1) {
        updateManager = [self _pushUpdateManagerToStack];
    } else {
        updateManager = [self _getUpdateManagerFromStack];
    }
    
    if (updates) {
        updates();
    }
    
    //NSAssert(_updateContextStep > 0, @"every invocation of -endUpdates must have a -beginUpdates invoking in front");
    
    [self _startUpdateAnimationWithUpdateManager:updateManager duration:duration delay:delay options:options completion:completion];
    [self _popUpdateManagerFromStack];
    _updateContextStep--;
}

- (void)performBatchUpdates:(void (^)(void))updates duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options completion:(void (^)(BOOL))completion {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath || !_numberOfSections || _reloadDataNeededFlag) {
        return;
    }
    
    _updateContextStep++;
    [self _lockLayoutSubviews];
    
    MPTableViewUpdateManager *updateManager;
    if (_updateContextStep > 1) {
        updateManager = [self _pushUpdateManagerToStack];
    } else {
        updateManager = [self _getUpdateManagerFromStack];
    }
    
    if (updates) {
        updates();
    }
    
    //NSAssert(_updateContextStep > 0, @"every invocation of -endUpdates must have a -beginUpdates invoking in front");
    
    NSParameterAssert(dampingRatio < MPTableViewMaxSize);
    [self _startUpdateAnimationWithUpdateManager:updateManager duration:duration delay:delay options:options usingSpringWithDamping:dampingRatio initialSpringVelocity:velocity completion:completion];
    [self _popUpdateManagerFromStack];
    _updateContextStep--;
}

- (id)dequeueReusableCellWithIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    
    MPTableViewCell *reusableCell;
    NSMutableArray *queue = [_reusableCellsDic objectForKey:identifier];
    if (queue.count) {
        reusableCell = [queue lastObject];
        [queue removeLastObject];
        reusableCell.hidden = NO;
    } else {
        reusableCell = nil;
    }
    
    if (!reusableCell && _registerCellsClassDic) {
        Class cellClass = [_registerCellsClassDic objectForKey:identifier];
        if (cellClass) {
            reusableCell = [[cellClass alloc] initWithReuseIdentifier:identifier];
        } else {
            reusableCell = nil;
        }
    }
    
    if (!reusableCell && _registerCellsNibDic) {
        UINib *nib = [_registerCellsNibDic objectForKey:identifier];
        if (nib) {
            reusableCell = [nib instantiateWithOwner:self options:nil][0];
            NSParameterAssert([reusableCell isKindOfClass:[MPTableViewCell class]]);
            reusableCell.reuseIdentifier = identifier;
        } else {
            reusableCell = nil;
        }
    }
    
    [reusableCell prepareForReuse];
    
    return reusableCell;
}

- (id)dequeueReusableViewWithIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    
    MPTableReusableView *reusableView;
    NSMutableArray *queue = [_reusableReusableViewsDic objectForKey:identifier];
    if (queue.count) {
        reusableView = [queue lastObject];
        [queue removeLastObject];
        reusableView.hidden = NO;
    } else {
        reusableView = nil;
    }
    
    if (!reusableView && _registerReusableViewsClassDic) {
        Class reusableViewClass = [_registerReusableViewsClassDic objectForKey:identifier];
        if (reusableViewClass) {
            reusableView = [[reusableViewClass alloc] initWithReuseIdentifier:identifier];
        } else {
            reusableView = nil;
        }
    }
    
    if (!reusableView && _registerReusableViewsNibDic) {
        UINib *nib = [_registerReusableViewsNibDic objectForKey:identifier];
        if (nib) {
            reusableView = [nib instantiateWithOwner:self options:nil][0];
            NSParameterAssert([reusableView isKindOfClass:[MPTableReusableView class]]);
            reusableView.reuseIdentifier = identifier;
        } else {
            reusableView = nil;
        }
    }
    
    [reusableView prepareForReuse];
    
    return reusableView;
}

- (void)registerClass:(Class)cellClass forCellReuseIdentifier:(NSString *)identifier {
    NSParameterAssert([cellClass isSubclassOfClass:[MPTableViewCell class]]);
    
    if (!_registerCellsClassDic) {
        _registerCellsClassDic = [[NSMutableDictionary alloc] init];
    }
    [_registerCellsClassDic setObject:cellClass forKey:identifier];
}

- (void)registerClass:(Class)reusableViewClass forReusableViewReuseIdentifier:(NSString *)identifier {
    NSParameterAssert([reusableViewClass isSubclassOfClass:[MPTableReusableView class]]);
    
    if (!_registerReusableViewsClassDic) {
        _registerReusableViewsClassDic = [[NSMutableDictionary alloc] init];
    }
    [_registerReusableViewsClassDic setObject:reusableViewClass forKey:identifier];
}

- (void)registerNib:(UINib *)nib forCellReuseIdentifier:(NSString *)identifier {
    NSParameterAssert(nib && identifier && [nib instantiateWithOwner:self options:nil].count);
    
    if (!_registerCellsNibDic) {
        _registerCellsNibDic = [[NSMutableDictionary alloc] init];
    }
    [_registerCellsNibDic setObject:nib forKey:identifier];
}

- (void)registerNib:(UINib *)nib forReusableViewReuseIdentifier:(NSString *)identifier {
    NSParameterAssert(nib && identifier && [nib instantiateWithOwner:self options:nil].count);
    
    if (!_registerReusableViewsNibDic) {
        _registerReusableViewsNibDic = [[NSMutableDictionary alloc] init];
    }
    [_registerReusableViewsNibDic setObject:nib forKey:identifier];
}

#pragma mark - -update-

- (MPTableViewUpdateManager *)_pushUpdateManagerToStack {
    if (!_updateManagerStack) { // update init
        _updateManagerStack = [[NSMutableArray alloc] init];
        _deleteCellsDic = [[NSMutableDictionary alloc] init];
        _deleteSectionViewsDic = [[NSMutableDictionary alloc] init];
        _insertCellsDic = [[NSMutableDictionary alloc] init];
        _insertSectionViewsDic = [[NSMutableDictionary alloc] init];
        _updateAnimationBlocks = [[NSMutableArray alloc] init];
        
        _updateExchangedOffscreenIndexPaths = [[NSMutableSet alloc] init];
        _updateExchangedSelectedIndexPaths = [[NSMutableSet alloc] init];
        
        _ignoredUpdateActions = [[NSMutableArray alloc] init];
    }
    
    MPTableViewUpdateManager *updateManager = [MPTableViewUpdateManager managerWithDelegate:self andSections:_sectionsAreaList];
    [_updateManagerStack addObject:updateManager];
    
    return updateManager;
}

- (MPTableViewUpdateManager *)_getUpdateManagerFromStack {
    MPTableViewUpdateManager *updateManager = [_updateManagerStack lastObject];
    if (!updateManager) {
        updateManager = [self _pushUpdateManagerToStack];
    }
    
    return updateManager;
}

- (void)_popUpdateManagerFromStack {
    if (_updateManagerStack.count > 1) { // at least one for reuse
        [_updateManagerStack removeLastObject];
    }
}

- (NSMutableArray *)_ignoredUpdateActions {
    return _ignoredUpdateActions;
}

- (MPTableViewEstimatedManager *)_mpEstimatedUpdateManager {
    if (!_estimatedUpdateManager) {
        _estimatedUpdateManager = [[MPTableViewEstimatedManager alloc] init];
        _estimatedUpdateManager.sections = _sectionsAreaList;
        _estimatedUpdateManager.delegate = self;
        
        _estimatedCellsDic = [[NSMutableDictionary alloc] init];
        _estimatedSectionViewsDic = [[NSMutableDictionary alloc] init];
    }
    
    return _estimatedUpdateManager;
}

- (void)set_updateDeleteOriginTopPosition:(CGFloat)_updateDeleteOriginTopPosition {
    __updateDeleteOriginTopPosition = _updateDeleteOriginTopPosition;
}

- (CGFloat)_updateDeleteOriginTopPosition {
    return __updateDeleteOriginTopPosition;
}

- (void)set_updateInsertOriginTopPosition:(CGFloat)_updateInsertOriginTopPosition {
    __updateInsertOriginTopPosition = _updateInsertOriginTopPosition;
}

- (CGFloat)_updateInsertOriginTopPosition {
    return __updateInsertOriginTopPosition;
}

- (void)_startUpdateAnimationWithUpdateManager:(MPTableViewUpdateManager *)updateManager duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options completion:(void (^)(BOOL finished))completion {
    [self _startUpdateAnimationWithUpdateManager:updateManager duration:duration delay:delay options:options usingSpringWithDamping:MPTableViewMaxSize initialSpringVelocity:MPTableViewMaxSize completion:completion];
}

- (void)_startUpdateAnimationWithUpdateManager:(MPTableViewUpdateManager *)updateManager duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity completion:(void (^)(BOOL finished))completion {
    if (_reloadDataNeededFlag) {
        return;
    }
    
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    if ([self __isEstimatedMode]) {
        [self _clipCellsBetween:_beginIndexPath and:_endIndexPath];
        [self _clipAndAdjustSectionViewsBetween:_beginIndexPath and:_endIndexPath];
    }
    [self _lockLayoutSubviews];
    _updateDataPreparing = YES; // when _updateDataPreparing is true, we can not start a new update transaction.
    _lastSuspendFooterSection = _lastSuspendHeaderSection = NSNotFound;
    __updateInsertOriginTopPosition = __updateDeleteOriginTopPosition = 0;
    
    if (_respond_numberOfSectionsInMPTableView) {
        NSUInteger numberOfSections = [_mpDataSource numberOfSectionsInMPTableView:self];
        if ([updateManager hasUpdateNodes]) {
            _numberOfSections = numberOfSections;
        } else {
            if (numberOfSections != _numberOfSections) {
                MPTableViewThrowUpdateException(@"check for the number of sections from data source");
            }
        }
    }
    updateManager.newCount = _numberOfSections;
    
    if (![updateManager formatNodesStable:[self __isContentMoving]]) {
        MPTableViewThrowUpdateException(@"check for update sections");
    }
    
    _updateAnimationStep++;
    
    CGFloat offset = [updateManager startUpdate];
    [updateManager resetManager];
    
    if (_numberOfSections) {
        _contentDrawArea.endPos += offset;
    } else {
        _contentDrawArea.endPos = _contentDrawArea.beginPos;
    }
    
    MPIndexPathStruct beginIndexPath, endIndexPath; // ...
    
    if (_contentDrawArea.beginPos >= _contentDrawArea.endPos) {
        beginIndexPath = _beginIndexPath = MPIndexPathStructMake(NSIntegerMax, MPSectionTypeFooter);
        endIndexPath = _endIndexPath = MPIndexPathStructMake(NSIntegerMin, MPSectionTypeHeader);
    } else {
        _beginIndexPath = [self _indexPathAtContentOffset:_currDrawArea.beginPos];
        _endIndexPath = [self _indexPathAtContentOffset:_currDrawArea.endPos];
        
        if (_contentOffset.beginPos > [self _contentInset].top && (self.contentSize.height + [self _contentInset].bottom + offset < _contentOffset.endPos)) { // when scrolling to the bottom, it needs to change content offset
            _contentOffsetChanged = YES;
            
            _contentOffset.endPos = self.contentSize.height + [self _contentInset].bottom + offset;
            _contentOffset.beginPos = _contentOffset.endPos - self.bounds.size.height;
            
            if (_contentOffset.beginPos < -[self _contentInset].top) {
                _contentOffset.beginPos = -[self _contentInset].top;
                _contentOffset.endPos = _contentOffset.beginPos + self.bounds.size.height;
            }
            
            _currDrawArea.beginPos = _contentOffset.beginPos - _contentDrawArea.beginPos;
            _currDrawArea.endPos = _contentOffset.endPos - _contentDrawArea.beginPos;
            
            beginIndexPath = [self _indexPathAtContentOffset:_currDrawArea.beginPos];
            endIndexPath = [self _indexPathAtContentOffset:_currDrawArea.endPos];
            
            // insertions off-screen before
            if ([self isUpdateForceReload] || ![self __isEstimatedMode]) {
                for (void (^action)(void) in _ignoredUpdateActions) {
                    action();
                }
            }
        } else {
            if (_movingIndexPath) {
                if ([_movingIndexPath compareIndexPathAt:_beginIndexPath] == NSOrderedAscending) {
                    _beginIndexPath = [_movingIndexPath structIndexPath];
                }
                if ([_movingIndexPath compareIndexPathAt:_endIndexPath] == NSOrderedDescending) {
                    _endIndexPath = [_movingIndexPath structIndexPath];
                }
            }
            
            beginIndexPath = _beginIndexPath;
            endIndexPath = _endIndexPath;
            
            [self _prefetchDataIfNeeded];
        }
    }
    [_ignoredUpdateActions removeAllObjects];
    
    [_displayedCellsDic addEntriesFromDictionary:_insertCellsDic];
    [_insertCellsDic removeAllObjects];
    [_displayedSectionViewsDic addEntriesFromDictionary:_insertSectionViewsDic];
    [_insertSectionViewsDic removeAllObjects];
    
    [_selectedIndexPaths unionSet:_updateExchangedSelectedIndexPaths];
    [_updateExchangedSelectedIndexPaths removeAllObjects];
    
    if (_estimatedCellsDic.count) { //
        for (MPTableViewCell *cell in _estimatedCellsDic.allValues) {
            [self _cacheCell:cell];
        }
        [_estimatedCellsDic removeAllObjects];
    }
    
    if (_estimatedSectionViewsDic.count) {
        for (MPTableReusableView *view in _estimatedSectionViewsDic.allValues) {
            [self _cacheSectionView:view];
        }
        [_estimatedSectionViewsDic removeAllObjects];
    }
    
    for (MPIndexPath *indexPath in _displayedCellsDic.allKeys) {
        if ([indexPath compareIndexPathAt:beginIndexPath] == NSOrderedAscending || [indexPath compareIndexPathAt:endIndexPath] == NSOrderedDescending) {
            if (_movingIndexPath && [_movingIndexPath compareRowSection:indexPath] == NSOrderedSame) {
                continue;
            }
            
            [_updateExchangedOffscreenIndexPaths addObject:indexPath]; // it should be cached when moving, but there is no bug
        }
    }
    
    for (MPIndexPath *indexPath in _displayedSectionViewsDic.allKeys) {
        MPTableViewSection *section = nil;
        
        if (self.style == MPTableViewStylePlain) {
            section = _sectionsAreaList[indexPath.section];
            
            if (_contentOffsetChanged && [self _needSuspendingSection:section withType:indexPath.row]) {
                MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                
                if ([sectionView isHidden]) { // animationNone
                    sectionView.frame = [self _suspendingFrameInSection:section type:indexPath.row];
                } else {
                    void (^animationBlock)(void) = ^{
                        sectionView.frame = [self _suspendingFrameInSection:section type:indexPath.row];
                    };
                    [_updateAnimationBlocks addObject:animationBlock];
                }
                continue;
            } else {
                if ([self _isSuspendingAtIndexPath:indexPath]) {
                    if (_contentOffsetChanged) {
                        if (indexPath.row == MPSectionTypeHeader) {
                            _currSuspendHeaderSection = NSNotFound;
                        } else {
                            _currSuspendFooterSection = NSNotFound;
                        }
                    } else {
                        continue;
                    }
                }
            }
        }
        
        if (_needPreparationDetected && [self _needPrepareToSuspendViewAt:section withType:indexPath.row]) {
            if (_contentOffsetChanged) {
                MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                
                if ([sectionView isHidden]) { // animationNone
                    sectionView.frame = [self _prepareToSuspendViewFrameAt:section withType:indexPath.row];
                } else {
                    void (^animationBlock)(void) = ^{
                        sectionView.frame = [self _prepareToSuspendViewFrameAt:section withType:indexPath.row];
                    };
                    [_updateAnimationBlocks addObject:animationBlock];
                }
            }
            continue;
        }
        
        if ([indexPath compareIndexPathAt:beginIndexPath] == NSOrderedAscending || [indexPath compareIndexPathAt:endIndexPath] == NSOrderedDescending) {
            [_updateExchangedOffscreenIndexPaths addObject:indexPath];
        } else {
            if (_contentOffsetChanged && self.style == MPTableViewStylePlain) { // all adjusting reset
                MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                if (!section) {
                    section = _sectionsAreaList[indexPath.section];
                }
                
                [self _contentOffsetChangedResetSectionView:sectionView inSection:section withType:indexPath.row];
            }
        }
    }
    
    if (_contentOffsetChanged) {
        if ([self __isEstimatedMode]) {
            if ([self isUpdateForceReload]) {
                CGFloat newOffset = [[self _mpEstimatedUpdateManager] startUpdate:beginIndexPath];
                if (newOffset != 0) {
                    MPTableViewThrowUpdateException(@"a critical bug");
                }
                _beginIndexPath = beginIndexPath;
                _endIndexPath = endIndexPath;
                [self _prefetchDataIfNeeded];
            }
        } else {
            if (self.style == MPTableViewStylePlain) {
                if (_currSuspendHeaderSection == NSNotFound && _contentOffset.beginPos - [self _contentInset].top >= _contentDrawArea.beginPos) {
                    [self _suspendSectionHeaderIfNeededAt:beginIndexPath];
                }
                // ...no need footer
            }
            [self _updateDisplayingBegin:beginIndexPath and:endIndexPath];
            [self _prefetchDataIfNeeded];
        }
    }
    
    CGSize contentSize = CGSizeMake(self.bounds.size.width, _contentDrawArea.endPos + self.tableFooterView.frame.size.height);
    if (!CGSizeEqualToSize(contentSize, _contentWrapperView.frame.size)) {
        _contentWrapperView.frame = CGRectMake(0, 0, contentSize.width, contentSize.height);
    }
    
    NSArray *updateAnimationBlocks = _updateAnimationBlocks;
    _updateAnimationBlocks = [[NSMutableArray alloc] init];
    
    NSDictionary *deleteCellsDic = nil;
    if (_deleteCellsDic.count) {
        deleteCellsDic = [NSDictionary dictionaryWithDictionary:_deleteCellsDic];
        [_deleteCellsDic removeAllObjects];
    }
    NSDictionary *deleteSectionViewsDic = nil;
    if (_deleteSectionViewsDic.count) {
        deleteSectionViewsDic = [NSDictionary dictionaryWithDictionary:_deleteSectionViewsDic];
        [_deleteSectionViewsDic removeAllObjects];
    }
    
    void (^animations)(void) = ^{
        if (offset != 0 && self.tableFooterView) {
            CGRect frame = self.tableFooterView.frame;
            frame.origin.y += offset;
            self.tableFooterView.frame = frame;
        }
        
        for (void (^animationBlock)(void) in updateAnimationBlocks) {
            animationBlock();
        }
        
        [super setContentSize:contentSize];
    };
    
    void (^animationCompletion)(BOOL finished) = ^(BOOL finished){
        [self _updateAnimationCompletionWithDeleteCells:deleteCellsDic deleteSectionViews:deleteSectionViewsDic];
        if (completion) {
            completion(finished);
        }
    };
    
    if (self.updateLayoutSubviewsOptionEnabled) {
        options |= UIViewAnimationOptionLayoutSubviews;
    }
    if (dampingRatio < MPTableViewMaxSize) {
        [UIView animateWithDuration:duration delay:delay usingSpringWithDamping:dampingRatio initialSpringVelocity:velocity options:options animations:animations completion:animationCompletion];
    } else {
        [UIView animateWithDuration:duration delay:delay options:options animations:animations completion:animationCompletion];
    }
    
    _contentOffsetChanged = NO;
    _updateDataPreparing = NO;
    [self _unlockLayoutSubviews];
}

- (void)_updateAnimationCompletionWithDeleteCells:(NSDictionary *)deleteCellsDic deleteSectionViews:(NSDictionary *)deleteSectionViewsDic {
    _updateAnimationStep--;
    
    if (_respond_didEndDisplayingCellForRowAtIndexPath) {
        for (MPIndexPath *indexPath in deleteCellsDic.allKeys) {
            MPTableViewCell *cell = [deleteCellsDic objectForKey:indexPath];
            [cell removeFromSuperview]; // alpha is hard to reset...
            
            [_mpDelegate MPTableView:self didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
        }
    } else {
        [deleteCellsDic.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }
    
    if (_respond_didEndDisplayingHeaderViewForSection || _respond_didEndDisplayingFooterViewForSection) {
        for (MPIndexPath *indexPath in deleteSectionViewsDic.allKeys) {
            MPTableReusableView *sectionView = [deleteSectionViewsDic objectForKey:indexPath];
            [sectionView removeFromSuperview];
            
            if (indexPath.row == MPSectionTypeHeader && _respond_didEndDisplayingHeaderViewForSection) {
                [_mpDelegate MPTableView:self didEndDisplayingHeaderView:sectionView forSection:indexPath.section];
            }
            if (indexPath.row == MPSectionTypeFooter && _respond_didEndDisplayingFooterViewForSection) {
                [_mpDelegate MPTableView:self didEndDisplayingFooterView:sectionView forSection:indexPath.section];
            }
        }
    } else {
        [deleteSectionViewsDic.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }
    
    if (_updateAnimationStep == 0) {
        [self _getDisplayingArea];
        MPIndexPathStruct beginIndexPathStruct;
        MPIndexPathStruct endIndexPathStruct;
        if (_contentDrawArea.beginPos >= _contentDrawArea.endPos) {
            beginIndexPathStruct = _beginIndexPath = MPIndexPathStructMake(NSIntegerMax, MPSectionTypeFooter);
            endIndexPathStruct = _endIndexPath = MPIndexPathStructMake(NSIntegerMin, MPSectionTypeHeader);
        } else {
            beginIndexPathStruct = [self _indexPathAtContentOffset:_currDrawArea.beginPos];
            endIndexPathStruct = [self _indexPathAtContentOffset:_currDrawArea.endPos];
        }
        [self _clipCellsBetween:beginIndexPathStruct and:endIndexPathStruct];
        [self _clipAndAdjustSectionViewsBetween:beginIndexPathStruct and:endIndexPathStruct];
        [_updateExchangedOffscreenIndexPaths removeAllObjects];
    }
}

//
- (void)_contentOffsetChangedResetSectionView:(MPTableReusableView *)sectionView inSection:(MPTableViewSection *)section withType:(MPSectionType)type {
    if ([sectionView isHidden]) {
        return;
    }
    
    void (^animationBlock)(void);
    if (type == MPSectionTypeHeader) {
        animationBlock = ^{
            CGRect frame;
            frame.origin.x = 0;
            frame.origin.y = section.beginPos + _contentDrawArea.beginPos;
            frame.size.width = self.bounds.size.width;
            frame.size.height = section.headerHeight;
            sectionView.frame = frame;
        };
    } else {
        animationBlock = ^{
            CGRect frame;
            frame.origin.x = 0;
            frame.origin.y = section.endPos - section.footerHeight + _contentDrawArea.beginPos;
            frame.size.width = self.bounds.size.width;
            frame.size.height = section.footerHeight;
            sectionView.frame = frame;
        };
    }
    [_updateAnimationBlocks addObject:animationBlock];
}

// frame.size.height must be bigger than the target height.
- (CGFloat)_updateGetOptimizedYWithFrame:(CGRect)frame toTargetY:(CGFloat)targetY {
    CGFloat temp = frame.origin.y;
    frame.origin.y = targetY;
    if (/*_updateTranslationalOptimization || */MPTableView_Onscreen) { //
        return targetY;
    }
    frame.origin.y = temp;
    CGFloat distance = targetY - frame.origin.y;
    
    if (fabs(distance) > self.bounds.size.height + frame.size.height) {
        if (distance > 0) {
            temp = frame.origin.y + self.bounds.size.height + frame.size.height + 1;
        } else {
            temp = frame.origin.y - self.bounds.size.height - frame.size.height - 1;
        }
        
        frame.origin.y = temp;
        if (targetY < _contentOffset.beginPos && CGRectGetMaxY(frame) >= _contentOffset.beginPos) { // deletion and contentOffset has been changed.
            temp = targetY;
        }
    } else {
        temp = targetY;
    }
    
    return temp;
}

- (BOOL)_updateNeedToAdjustingBegin:(CGFloat)begin andEnd:(CGFloat)end withOffset:(CGFloat)offset {
    if (offset > 0) {
        CGFloat newEnd = end + offset;
        return begin <= _contentOffset.endPos && newEnd >= _contentOffset.beginPos;
    } else if (offset < 0) {
        CGFloat newBegin = begin + offset;
        return newBegin <= _contentOffset.endPos && end >= _contentOffset.beginPos;
    } else {
        return begin <= _contentOffset.endPos && end >= _contentOffset.beginPos;
    }
}

- (BOOL)__updateNeedToAnimateSection:(MPTableViewSection *)section updateType:(MPTableViewUpdateType)type andOffset:(CGFloat)offset {
    if (MPTableViewUpdateTypeStable(type)) {
        if (section.beginPos > _currDrawArea.endPos || section.endPos < _currDrawArea.beginPos) {
            return NO;
        } else {
            return YES;
        }
    } else if (MPTableViewUpdateTypeUnstable(type)) { // reload is split into a deletion and an insertion
        if (section.section < _beginIndexPath.section || section.section > _endIndexPath.section) {
            if (_updateExchangedOffscreenIndexPaths.count) {
                for (const MPIndexPath *indexPath in _updateExchangedOffscreenIndexPaths) {
                    if (indexPath.section == section.section) {
                        return YES;
                    }
                }
            }
            
            return NO;
        } else {
            return YES;
        }
    } else { // adjust
        if ([self isUpdating] && [self isUpdateForceReload] && !_movingIndexPath) {
            return YES;
        }
        
        if (section.updatePart) {
            if (section.section > _endIndexPath.section && section.beginPos + offset > _currDrawArea.endPos) {
                return NO;
            } else {
                return YES;
            }
        } else {
            if ((section.section < _beginIndexPath.section || section.section > _endIndexPath.section) && ![self _updateNeedToAdjustingBegin:section.beginPos + _contentDrawArea.beginPos andEnd:section.endPos + _contentDrawArea.beginPos withOffset:offset]) {
                return NO;
            } else {
                return YES;
            }
        }
    }
}

#pragma mark - cell update delegate

- (CGFloat)__updateInsertCellHeightAtIndexPath:(MPIndexPath *)indexPath {
    CGFloat cellHeight;
    if (_respond_estimatedHeightForRowAtIndexPath) {
        MPTableViewSection *section = _sectionsAreaList[indexPath.section];
        CGFloat beginPos = [section rowPositionBeginAt:indexPath.row] + _contentDrawArea.beginPos;
        cellHeight = [_mpDataSource MPTableView:self estimatedHeightForRowAtIndexPath:indexPath];
        CGRect frame = CGRectMake(0, beginPos, self.bounds.size.width, cellHeight);
        
        if ([self isUpdateForceReload] || MPTableView_Onscreen) {
            if (_respond_heightForRowAtIndexPath) {
                cellHeight = ([_mpDataSource MPTableView:self heightForRowAtIndexPath:indexPath]);
            } else {
                MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
                cellHeight = frame.size.height = _MP_UpdateLayoutSizeForCell(cell, frame.size.width);
                
                if (MPTableView_Offscreen) {
                    [self _cacheCell:cell];
                } else {
                    [_estimatedCellsDic setObject:cell forKey:indexPath];
                }
            }
        }
    } else if (_respond_heightForRowAtIndexPath) {
        cellHeight = ([_mpDataSource MPTableView:self heightForRowAtIndexPath:indexPath]);
    } else {
        cellHeight = self.rowHeight;
    }
    
    if (cellHeight < 0 || cellHeight > MPTableViewMaxSize) {
        @throw [NSException exceptionWithName:MPTableViewException reason:@"cell height" userInfo:nil];
    }
    
    return cellHeight;
}

- (CGFloat)__updateMoveInCellHeightAtIndexPath:(MPIndexPath *)indexPath originIndexPath:(MPIndexPath *)originIndexPath originHeight:(CGFloat)originHeight withDistance:(CGFloat)distance {
    if (_respond_estimatedHeightForRowAtIndexPath && ![self isUpdateForceReload]) {
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        if (![self _updateNeedToAdjustingBegin:frame.origin.y andEnd:CGRectGetMaxY(frame) withOffset:distance]) {
            return originHeight;
        }
    }
    
    CGFloat cellHeight;
    if (_respond_heightForRowAtIndexPath) {
        cellHeight = ([_mpDataSource MPTableView:self heightForRowAtIndexPath:indexPath]);
    } else if (_respond_estimatedHeightForRowAtIndexPath) {
        if ([_displayedCellsDic objectForKey:originIndexPath]) {
            cellHeight = originHeight;
        } else {
            MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            CGRect frame = [self _cellFrameAtIndexPath:indexPath];
            cellHeight = _MP_UpdateLayoutSizeForCell(cell, frame.size.width);
            
            frame.size.height = cellHeight;
            if (![self _updateNeedToAdjustingBegin:frame.origin.y andEnd:CGRectGetMaxY(frame) withOffset:distance]) {
                [self _cacheCell:cell];
            } else {
                [_estimatedCellsDic setObject:cell forKey:indexPath];
            }
        }
    } else {
        cellHeight = self.rowHeight;
    }
    
    if (cellHeight < 0 || cellHeight > MPTableViewMaxSize) {
        @throw [NSException exceptionWithName:MPTableViewException reason:@"cell height" userInfo:nil];
    }
    
    return cellHeight;
}

- (CGFloat)__rebuildCellAtSection:(NSInteger)section fromOriginSection:(NSInteger)originSection atIndex:(NSInteger)index {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:index inSection:section];
    if (originSection != section) {
        indexPath.section = originSection;
        if (!_respond_heightForHeaderInSection && [_displayedCellsDic objectForKey:indexPath]) {
            return 0;
        } else {
            indexPath.section = section;
        }
    }
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    
    if ([self __isEstimatedMode] && ![self isUpdateForceReload] && MPTableView_Offscreen) {
        return frame.origin.y > _contentOffset.endPos ? MPTableViewMaxSize : 0;
    } else {
        CGFloat cellHeight = frame.size.height;
        
        if (_respond_heightForRowAtIndexPath) {
            frame.size.height = ([_mpDataSource MPTableView:self heightForRowAtIndexPath:indexPath]);
        } else if (_respond_estimatedHeightForRowAtIndexPath) {
            MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            frame.size.height = _MP_UpdateLayoutSizeForCell(cell, frame.size.width);
            
            if (MPTableView_Offscreen) {
                [self _cacheCell:cell];
            } else {
                [_estimatedCellsDic setObject:cell forKey:indexPath];
            }
        }
        
        return frame.size.height - cellHeight;
    }
}

- (void)__updateSection:(NSInteger)originSection deleteCellAtIndex:(NSInteger)index withAnimation:(MPTableViewRowAnimation)animation isSectionAnimation:(MPTableViewSection *)sectionPosition {
    if (!_updateExchangedOffscreenIndexPaths.count) {
        MPIndexPathStruct indexPath_ = MPIndexPathStructMake(originSection, index);
        if (MPCompareIndexPath(indexPath_, _beginIndexPath) == NSOrderedAscending || MPCompareIndexPath(indexPath_, _endIndexPath) == NSOrderedDescending) {
            return ;
        }
    }
    
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:index inSection:originSection];
    
    if ([_selectedIndexPaths containsObject:indexPath]) {
        [_selectedIndexPaths removeObject:indexPath];
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    if (!cell) {
        return;
    }
    CGFloat updateDeleteOriginTopPosition = __updateDeleteOriginTopPosition + _contentDrawArea.beginPos;
    
    if (animation == MPTableViewRowAnimationCustom) {
        if (_respond_beginToDeleteCellForRowAtIndexPath) {
            [_mpDelegate MPTableView:self beginToDeleteCell:cell forRowAtIndexPath:indexPath withAnimationPathPosition:updateDeleteOriginTopPosition];
        }
    } else {
        if (animation == MPTableViewRowAnimationNone) {
            [self _cacheCell:cell];
        } else {
            if (animation == MPTableViewRowAnimationTop) {
                [_contentWrapperView sendSubviewToBack:cell];
            }
            if (animation == MPTableViewRowAnimationBottom) {
                [_contentWrapperView bringSubviewToFront:cell];
            }
            
            void (^animationBlock)(void) = ^{
                CGRect targetFrame = MPTableViewDisappearViewFrameWithRowAnimation(cell, updateDeleteOriginTopPosition, animation, sectionPosition);
                
                CGFloat targetY = targetFrame.origin.y;
                targetFrame.origin.y = [self _updateGetOptimizedYWithFrame:cell.frame toTargetY:targetY];
                cell.frame = targetFrame;
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
            [_deleteCellsDic setObject:cell forKey:indexPath];
        }
    }
    
    [_displayedCellsDic removeObjectForKey:indexPath];
    [_updateExchangedOffscreenIndexPaths removeObject:indexPath];
}

- (BOOL)__updateSection:(NSInteger)section insertCellAtIndex:(NSInteger)index withAnimation:(MPTableViewRowAnimation)animation isSectionAnimation:(MPTableViewSection *)sectionPosition {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:index inSection:section];
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    if (MPTableView_Offscreen) { //
        return NO;
    } else {
        MPTableViewCell *cell = nil;
        if (_respond_estimatedHeightForRowAtIndexPath && !_respond_heightForRowAtIndexPath) {
            cell = [_estimatedCellsDic objectForKey:indexPath];
        }
        
        if (!cell) {
            cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
        } else {
            [_estimatedCellsDic removeObjectForKey:indexPath];
        }
        
        cell.frame = frame;
        
        if (_respond_willDisplayCellForRowAtIndexPath) {
            [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
        }
        
        [self _addSubviewIfNecessaryForCell:cell];
        
        CGFloat updateInsertOriginTopPosition = __updateInsertOriginTopPosition + _contentDrawArea.beginPos;
        if (animation == MPTableViewRowAnimationCustom) {
            if (_respond_beginToInsertCellForRowAtIndexPath) {
                [_mpDelegate MPTableView:self beginToInsertCell:cell forRowAtIndexPath:indexPath withAnimationPathPosition:updateInsertOriginTopPosition];
            }
        } else {
            if (animation != MPTableViewRowAnimationNone) {
                if (animation == MPTableViewRowAnimationTop) {
                    [_contentWrapperView sendSubviewToBack:cell];
                }
                if (animation == MPTableViewRowAnimationBottom) {
                    [_contentWrapperView bringSubviewToFront:cell];
                }
                
                CGRect targetFrame = MPTableViewDisappearViewFrameWithRowAnimation(cell, updateInsertOriginTopPosition, animation, sectionPosition);
                
                targetFrame.origin.y = [self _updateGetOptimizedYWithFrame:cell.frame toTargetY:targetFrame.origin.y];
                
                cell.frame = targetFrame;
                
                void (^animationBlock)(void) = ^{
                    MPTableViewDisplayViewFrameWithRowAnimation(cell, frame, animation, sectionPosition);
                };
                
                [_updateAnimationBlocks addObject:animationBlock];
            }
        }
        [_insertCellsDic setObject:cell forKey:indexPath];
    }
    
    return YES;
}

- (BOOL)__updateSection:(NSInteger)section moveInCellAtIndex:(NSInteger)index fromOriginIndexPath:(MPIndexPath *)originIndexPath withOriginHeight:(CGFloat)originHeight withDistance:(CGFloat)distance {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:index inSection:section];
    
    if ([_selectedIndexPaths containsObject:originIndexPath]) {
        [_selectedIndexPaths removeObject:originIndexPath];
        [_updateExchangedSelectedIndexPaths addObject:indexPath];
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:originIndexPath];
    if (cell) {
        [_displayedCellsDic removeObjectForKey:originIndexPath];
        [_updateExchangedOffscreenIndexPaths removeObject:originIndexPath];
    }
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    
    if (cell) {
        [_insertCellsDic setObject:cell forKey:indexPath];
        
        if (_movingIndexPath) {
            return YES;
        }
        
        [_contentWrapperView bringSubviewToFront:cell];
        
        void (^animationBlock)(void) = ^{
            cell.frame = frame;
        };
        
        [_updateAnimationBlocks addObject:animationBlock];
    } else {
        if (![self _updateNeedToAdjustingBegin:frame.origin.y - distance andEnd:CGRectGetMaxY(frame) - distance withOffset:distance]) {
            return NO;
        }
        
        if (_respond_estimatedHeightForRowAtIndexPath && !_respond_heightForRowAtIndexPath) {
            cell = [_estimatedCellsDic objectForKey:indexPath];
            if (cell) {
                [_estimatedCellsDic removeObjectForKey:indexPath];
            }
        }
        
        if (!cell) {
            cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
        }
        
        CGFloat currOriginY = frame.origin.y;
        CGFloat currHeight = frame.size.height;
        frame.size.height = originHeight;
        frame.origin.y -= distance;
        cell.frame = frame;
        frame.origin.y = currOriginY;
        frame.size.height = currHeight;
        
        if (_respond_willDisplayCellForRowAtIndexPath) {
            [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
        }
        
        [self _addSubviewIfNecessaryForCell:cell];
        [_contentWrapperView bringSubviewToFront:cell];
        
        if ([_updateExchangedSelectedIndexPaths containsObject:indexPath]) {
            [cell setSelected:YES];
        }
        
        [_insertCellsDic setObject:cell forKey:indexPath];
        
        void (^animationBlock)(void) = ^{
            cell.frame = frame;
        };
        
        [_updateAnimationBlocks addObject:animationBlock];
    }
    
    return YES;
}

- (CGFloat)__updateSection:(NSInteger)section originSection:(NSInteger)originSection adjustCellAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex withOffset:(CGFloat)cellOffset {
    
    CGFloat newOffset = 0;
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:originIndex inSection:originSection];
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    
    CGRect frame;
    
    if (!cell) {
        indexPath.row = currIndex;
        indexPath.section = section;
        frame = [self _cellFrameAtIndexPath:indexPath];
        if (![self isUpdateForceReload] && ![self _updateNeedToAdjustingBegin:frame.origin.y - cellOffset andEnd:CGRectGetMaxY(frame) - cellOffset withOffset:cellOffset]) {
            return 0;
        } else {
            CGFloat originHeight = frame.size.height;
            if (!_movingIndexPath) {
                if (_respond_heightForRowAtIndexPath) {
                    frame.size.height = [_mpDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
                } else if (_respond_estimatedHeightForRowAtIndexPath) {
                    cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
                    frame.size.height = _MP_UpdateLayoutSizeForCell(cell, frame.size.width);
                }
                newOffset = frame.size.height - originHeight;
                
                if (![self _updateNeedToAdjustingBegin:frame.origin.y - cellOffset andEnd:CGRectGetMaxY(frame) - cellOffset withOffset:cellOffset]) {
                    if (cell) {
                        [self _cacheCell:cell];
                    }
                    return newOffset;
                }
            }
            
            if (!cell) {
                cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            }
            
            CGFloat currOriginY = frame.origin.y;
            CGFloat currHeight = frame.size.height;
            frame.origin.y -= cellOffset;
            frame.size.height = originHeight;
            cell.frame = frame;
            frame.origin.y = currOriginY;
            frame.size.height = currHeight;
            
            if (_respond_willDisplayCellForRowAtIndexPath) {
                [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
            }
            
            [self _addSubviewIfNecessaryForCell:cell];
            [_insertCellsDic setObject:cell forKey:indexPath];
            
            if (section == originSection && currIndex == originIndex) {
                if ([_selectedIndexPaths containsObject:indexPath]) {
                    [cell setSelected:YES];
                }
            } else {
                if ([_updateExchangedSelectedIndexPaths containsObject:indexPath]) {
                    [cell setSelected:YES];
                }
            }
            
            void (^animationBlock)(void) = ^{
                cell.frame = frame;
            };
            [_updateAnimationBlocks addObject:animationBlock];
        }
    } else {
        [_updateExchangedOffscreenIndexPaths removeObject:indexPath];
        if (originIndex != currIndex || section != originSection) {
            [_displayedCellsDic removeObjectForKey:indexPath];
            indexPath.row = currIndex;
            indexPath.section = section;
            [_insertCellsDic setObject:cell forKey:indexPath];
        }
        
        frame = cell.frame;
        if (_respond_heightForRowAtIndexPath && !_movingIndexPath) {
            indexPath.row = currIndex;
            indexPath.section = section;
            CGFloat cellHeight = frame.size.height;
            
            frame.size.height = [_mpDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
            newOffset = frame.size.height - cellHeight;
        }
        
        frame.origin.y += cellOffset;
        void (^animationBlock)(void) = ^{
            cell.frame = frame;
        };
        [_updateAnimationBlocks addObject:animationBlock];
    }
    
    return newOffset;
}

- (BOOL)__updateSection:(NSInteger)section originSection:(NSInteger)originSection adjustCellAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex {
    if (originSection != section || originIndex != currIndex) {
        for (const MPIndexPath *indexPath in _selectedIndexPaths) {
            if (indexPath.section == originSection && indexPath.row == originIndex) {
                [_selectedIndexPaths removeObject:indexPath];
                [_updateExchangedSelectedIndexPaths addObject:[MPIndexPath indexPathForRow:currIndex inSection:section]];
                break;
            }
        }
    }
    
    if (_updateExchangedOffscreenIndexPaths.count) {
        MPIndexPath *indexPath = [MPIndexPath indexPathForRow:originIndex inSection:originSection];
        return [_updateExchangedOffscreenIndexPaths containsObject:indexPath];
    } else {
        return NO;
    }
}

#pragma mark - sectionView update delegate

- (BOOL)_updateSectionViewNeedDisplayAt:(MPTableViewSection *)section andType:(MPSectionType)type withOffset:(CGFloat)offset {
    BOOL onscreen;
    
    if (type == MPSectionTypeHeader) {
        CGFloat begin = section.beginPos - offset + _contentDrawArea.beginPos;
        CGFloat end = section.beginPos + section.headerHeight - offset + _contentDrawArea.beginPos;
        onscreen = [self _updateNeedToAdjustingBegin:begin andEnd:end withOffset:offset];
    } else {
        CGFloat begin = section.endPos - section.footerHeight - offset + _contentDrawArea.beginPos;
        CGFloat end = section.endPos - offset + _contentDrawArea.beginPos;
        onscreen = [self _updateNeedToAdjustingBegin:begin andEnd:end withOffset:offset];
    }
    
    if (onscreen || (self.style == MPTableViewStylePlain && [self _needSuspendingSection:section withType:type]) || [self _needPrepareToSuspendViewAt:section withType:type]) {
        return YES;
    } else {
        return NO;
    }
}

- (CGFloat)_updateLayoutSizeForSectionViewAtSection:(NSInteger)section withType:(MPSectionType)type baseHeight:(CGFloat)baseHeight withOffset:(CGFloat)offset {
    MPTableReusableView *sectionView = nil;
    CGFloat height = 0;
    
    if (type == MPSectionTypeHeader) {
        sectionView = [_mpDataSource MPTableView:self viewForHeaderInSection:section];
    } else {
        sectionView = [_mpDataSource MPTableView:self viewForFooterInSection:section];
    }
    
    if (sectionView) {
        CGFloat width = self.bounds.size.width;
        [UIView performWithoutAnimation:^{
            CGRect frame = _MP_SetViewWidth(sectionView, width);
            [sectionView layoutIfNeeded];
            frame.size.height = [sectionView systemLayoutSizeFittingSize:CGSizeMake(width, 0)].height;
            sectionView.frame = frame;
        }];
        height = sectionView.frame.size.height;
        
        if ([self isUpdateForceReload] && ![self _updateSectionViewNeedDisplayAt:_sectionsAreaList[section] andType:type withOffset:offset]) {
            [self _cacheSectionView:sectionView];
        } else {
            MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:section];
            [_estimatedSectionViewsDic setObject:sectionView forKey:indexPath];
        }
    } else if (baseHeight) {
        height = baseHeight;
    }
    
    return height;
}

NS_INLINE CGFloat _MP_UpdateLayoutSizeForCell(MPTableViewCell *cell, CGFloat width) {
    [UIView performWithoutAnimation:^{
        CGRect frame = _MP_SetViewWidth(cell, width);
        [cell layoutIfNeeded];
        frame.size.height = [cell systemLayoutSizeFittingSize:CGSizeMake(width, 0)].height;
        cell.frame = frame;
    }];
    
    return cell.frame.size.height;
}

- (MPTableViewSection *)__updateGetSectionAt:(NSInteger)sectionIndex {
    MPTableViewSection *section = [MPTableViewSection section];
    section.section = sectionIndex;
    
    CGFloat offset = 0;
    if (_sectionsAreaList.count && sectionIndex > 0) {
        MPTableViewSection *preSection = _sectionsAreaList[sectionIndex - 1];
        offset = preSection.endPos;
    }
    
    [self _initializeSection:section withOffset:offset];
    
    return section;
}

- (CGFloat)__updateGetHeaderHeightInSection:(MPTableViewSection *)section fromOriginSection:(NSInteger)originSection withOffset:(CGFloat)offset force:(BOOL)force {
    if (_movingIndexPath) {
        return -1;
    }
    
    if (!_respond_heightForHeaderInSection && [_displayedSectionViewsDic objectForKey:[MPIndexPath indexPathForRow:MPSectionTypeHeader inSection:originSection]]) {
        return -1;
    }
    
    if (!force && ![self _updateSectionViewNeedDisplayAt:section andType:MPSectionTypeHeader withOffset:offset]) {
        return -1;
    }
    
    if (_respond_heightForHeaderInSection) {
        return [_mpDataSource MPTableView:self heightForHeaderInSection:section.section];
    } else if (_respond_estimatedHeightForHeaderInSection) {
        CGFloat height = [self _updateLayoutSizeForSectionViewAtSection:section.section withType:MPSectionTypeHeader baseHeight:-1 withOffset:offset];
        return height;
    }
    
    return -1;
}

- (CGFloat)__updateGetFooterHeightInSection:(MPTableViewSection *)section fromOriginSection:(NSInteger)originSection withOffset:(CGFloat)offset force:(BOOL)force {
    if (_movingIndexPath) {
        return -1;
    }
    
    if (!_respond_heightForFooterInSection && [_displayedSectionViewsDic objectForKey:[MPIndexPath indexPathForRow:MPSectionTypeFooter inSection:originSection]]) {
        return -1;
    }
    
    if (!force && ![self _updateSectionViewNeedDisplayAt:section andType:MPSectionTypeFooter withOffset:offset]) {
        return -1;
    }
    
    if (_respond_heightForFooterInSection) {
        return [_mpDataSource MPTableView:self heightForFooterInSection:section.section];
    } else if (_respond_estimatedHeightForFooterInSection) {
        CGFloat height = [self _updateLayoutSizeForSectionViewAtSection:section.section withType:MPSectionTypeFooter baseHeight:-1 withOffset:offset];
        return height;
    }
    
    return -1;
}

- (BOOL)_needSuspendingSection:(MPTableViewSection *)section withType:(MPSectionType)type {
    if (type == MPSectionTypeHeader) {
        CGFloat beginPos = _currDrawArea.beginPos + [self _contentInset].top;
        if (section.headerHeight && section.beginPos <= beginPos && section.endPos >= beginPos) {
            if (_lastSuspendHeaderSection == NSNotFound) {
                _lastSuspendHeaderSection = _currSuspendHeaderSection;
            }
            _currSuspendHeaderSection = section.section;
            return YES;
        } else {
            return NO;
        }
    } else {
        CGFloat endPos = _currDrawArea.endPos - [self _contentInset].bottom;
        if (section.footerHeight && section.beginPos <= endPos && section.endPos >= endPos) {
            if (_lastSuspendFooterSection == NSNotFound) {
                _lastSuspendFooterSection = _currSuspendFooterSection;
            }
            _currSuspendFooterSection = section.section;
            return YES;
        } else {
            return NO;
        }
    }
}

- (void)__updateDeleteSectionViewAtIndex:(NSInteger)index withType:(MPSectionType)type withAnimation:(MPTableViewRowAnimation)animation withDeleteSection:(MPTableViewSection *)deleteSection {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:index];
    
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    
    if (self.style == MPTableViewStylePlain) {
        if (type == MPSectionTypeHeader) {
            if (_lastSuspendHeaderSection == NSNotFound && _currSuspendHeaderSection == index) {
                _lastSuspendHeaderSection = _currSuspendHeaderSection;
                _currSuspendHeaderSection = NSNotFound;
            }
        } else {
            if (_lastSuspendFooterSection == NSNotFound && _currSuspendFooterSection == index) {
                _lastSuspendFooterSection = _currSuspendFooterSection;
                _currSuspendFooterSection = NSNotFound;
            }
        }
    }
    
    if (!sectionView) {
        return;
    }
    
    CGFloat updateDeleteOriginTopPosition = __updateDeleteOriginTopPosition + _contentDrawArea.beginPos;
    
    if (animation == MPTableViewRowAnimationCustom) {
        if (type == MPSectionTypeHeader) {
            if (_respond_beginToDeleteHeaderViewForSection) {
                [_mpDelegate MPTableView:self beginToDeleteHeaderView:sectionView forSection:index withAnimationPathPosition:updateDeleteOriginTopPosition];
            }
        } else {
            if (_respond_beginToDeleteFooterViewForSection) {
                [_mpDelegate MPTableView:self beginToDeleteFooterView:sectionView forSection:index withAnimationPathPosition:updateDeleteOriginTopPosition];
            }
        }
    } else {
        if (animation == MPTableViewRowAnimationNone) {
            [self _cacheSectionView:sectionView];
        } else {
            if (animation == MPTableViewRowAnimationTop) {
                [self insertSubview:sectionView aboveSubview:_contentWrapperView];
            }
            if (animation == MPTableViewRowAnimationBottom) {
                [self bringSubviewToFront:sectionView];
            }
            
            void (^animationBlock)(void) = ^{
                CGRect targetFrame = MPTableViewDisappearViewFrameWithRowAnimation(sectionView, updateDeleteOriginTopPosition, animation, deleteSection);
                
                if (animation != MPTableViewRowAnimationNone) {
                    CGFloat targetY = targetFrame.origin.y;
                    targetFrame.origin.y = [self _updateGetOptimizedYWithFrame:sectionView.frame toTargetY:targetY];
                    sectionView.frame = targetFrame;
                }
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
            [_deleteSectionViewsDic setObject:sectionView forKey:indexPath];
        }
    }
    
    [_displayedSectionViewsDic removeObjectForKey:indexPath];
    [_updateExchangedOffscreenIndexPaths removeObject:indexPath];
}

- (BOOL)__updateInsertSectionViewAtIndex:(NSInteger)index withType:(MPSectionType)type withAnimation:(MPTableViewRowAnimation)animation withInsertSection:(MPTableViewSection *)insertSection {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:index];
    
    CGRect frame;
    if (self.style == MPTableViewStylePlain) {
        if ([self _needSuspendingSection:insertSection withType:type]) {
            frame = [self _suspendingFrameInSection:insertSection type:type];
        } else if ([self _needPrepareToSuspendViewAt:insertSection withType:type]) {
            frame = [self _prepareToSuspendViewFrameAt:insertSection withType:type];
        } else {
            frame = [self _sectionViewFrameAtIndexPath:indexPath];
        }
    } else {
        frame = [self _sectionViewFrameAtIndexPath:indexPath];
    }
    
    if (MPTableView_Offscreen) { //
        return NO;
    } else {
        MPTableReusableView *sectionView = nil;
        if (type == MPSectionTypeHeader && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        } else if (type == MPSectionTypeFooter && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        }
        
        if (!sectionView) {
            sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
        } else {
            [_estimatedSectionViewsDic removeObjectForKey:indexPath];
        }
        
        if (!sectionView) {
            return YES;
        }
        sectionView.frame = frame;
        
        if (type == MPSectionTypeHeader) {
            if (_respond_willDisplayHeaderViewForSection) {
                [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
            }
        } else {
            if (_respond_willDisplayFooterViewForSection) {
                [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
            }
        }
        
        [self _addSubviewIfNecessaryForSectionView:sectionView];
        
        CGFloat updateInsertOriginTopPosition = __updateInsertOriginTopPosition + _contentDrawArea.beginPos;
        if (animation == MPTableViewRowAnimationCustom) {
            if (type == MPSectionTypeHeader) {
                if (_respond_beginToInsertHeaderViewForSection) {
                    [_mpDelegate MPTableView:self beginToInsertHeaderView:sectionView forSection:index withAnimationPathPosition:updateInsertOriginTopPosition];
                }
            } else {
                if (_respond_beginToInsertFooterViewForSection) {
                    [_mpDelegate MPTableView:self beginToInsertFooterView:sectionView forSection:index withAnimationPathPosition:updateInsertOriginTopPosition];
                }
            }
        } else {
            if (animation == MPTableViewRowAnimationNone) {
                
            } else {
                if (animation == MPTableViewRowAnimationTop) {
                    [self insertSubview:sectionView aboveSubview:_contentWrapperView];
                }
                if (animation == MPTableViewRowAnimationBottom) {
                    [self bringSubviewToFront:sectionView];
                }
                
                CGRect targetFrame = MPTableViewDisappearViewFrameWithRowAnimation(sectionView, updateInsertOriginTopPosition, animation, insertSection);
                
                targetFrame.origin.y = [self _updateGetOptimizedYWithFrame:sectionView.frame toTargetY:targetFrame.origin.y];
                
                sectionView.frame = targetFrame;
                
                void (^animationBlock)(void) = ^{
                    MPTableViewDisplayViewFrameWithRowAnimation(sectionView, frame, animation, insertSection);
                };
                
                [_updateAnimationBlocks addObject:animationBlock];
            }
        }
        
        [_insertSectionViewsDic setObject:sectionView forKey:indexPath];
    }
    
    return YES;
}

- (BOOL)__updateMoveInSectionViewAtIndex:(NSInteger)index fromOriginIndex:(NSInteger)originIndex withType:(MPSectionType)type withOriginHeight:(CGFloat)originHeight withDistance:(CGFloat)distance {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:index];
    MPIndexPath *originIndexPath = [MPIndexPath indexPathForRow:type inSection:originIndex];
    
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:originIndexPath];
    if (sectionView) {
        [_displayedSectionViewsDic removeObjectForKey:originIndexPath];
        [_updateExchangedOffscreenIndexPaths removeObject:originIndexPath];
    }
    CGRect frame = [self _sectionViewFrameAtIndexPath:indexPath];
    CGFloat originY = frame.origin.y;
    
    if (self.style == MPTableViewStylePlain) {
        MPTableViewSection *section = _sectionsAreaList[index];
        if ([self _needSuspendingSection:section withType:type]) {
            frame = [self _suspendingFrameInSection:section type:type];
        } else {
            if (type == MPSectionTypeHeader) {
                if (_lastSuspendHeaderSection == NSNotFound && _currSuspendHeaderSection == originIndex) {
                    _lastSuspendHeaderSection = _currSuspendHeaderSection;
                    _currSuspendHeaderSection = NSNotFound;
                }
            } else {
                if (_lastSuspendFooterSection == NSNotFound && _currSuspendFooterSection == originIndex) {
                    _lastSuspendFooterSection = _currSuspendFooterSection;
                    _currSuspendFooterSection = NSNotFound;
                }
            }
            
            if ([self _needPrepareToSuspendViewAt:section withType:type]) {
                frame = [self _prepareToSuspendViewFrameAt:section withType:type];
            }
        }
    }
    
    if (sectionView) {
        
        [_insertSectionViewsDic setObject:sectionView forKey:indexPath];
        
        [self bringSubviewToFront:sectionView];
        
        void (^animationBlock)(void) = ^{
            sectionView.frame = frame;
        };
        
        [_updateAnimationBlocks addObject:animationBlock];
    } else {
        if (![self _updateNeedToAdjustingBegin:frame.origin.y - distance andEnd:CGRectGetMaxY(frame) - distance withOffset:distance]) {
            return NO;
        }
        
        if (type == MPSectionTypeHeader && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        } else if (type == MPSectionTypeFooter && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        }
        
        if (!sectionView) {
            sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
        } else {
            [_estimatedSectionViewsDic removeObjectForKey:indexPath];
        }
        
        if (!sectionView) {
            return YES;
        }
        
        CGFloat currOriginY = frame.origin.y;
        CGFloat currHeight = frame.size.height;
        frame.origin.y = originY - distance;
        frame.size.height = originHeight;
        sectionView.frame = frame;
        frame.size.height = currHeight;
        frame.origin.y = currOriginY;
        
        if (type == MPSectionTypeHeader) {
            if (_respond_willDisplayHeaderViewForSection) {
                [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
            }
        } else {
            if (_respond_willDisplayFooterViewForSection) {
                [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
            }
        }
        
        [self _addSubviewIfNecessaryForSectionView:sectionView];
        [self bringSubviewToFront:sectionView];
        
        [_insertSectionViewsDic setObject:sectionView forKey:indexPath];
        
        void (^animationBlock)(void) = ^{
            sectionView.frame = frame;
        };
        
        [_updateAnimationBlocks addObject:animationBlock];
    }
    
    return YES;
}

- (void)__updateAdjustSectionViewAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex withType:(MPSectionType)type withOriginHeight:(CGFloat)originHeight withSectionOffset:(CGFloat)sectionOffset {
    
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:originIndex];
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    
    indexPath.section = currIndex;
    CGRect frame = [self _sectionViewFrameAtIndexPath:indexPath];
    indexPath.section = originIndex;
    
    if (self.style == MPTableViewStylePlain) {
        MPTableViewSection *section = _sectionsAreaList[currIndex];
        if ([self _needSuspendingSection:section withType:type]) {
            frame = [self _suspendingFrameInSection:section type:type];
        } else {
            if (type == MPSectionTypeHeader) {
                if (_lastSuspendHeaderSection == NSNotFound && _currSuspendHeaderSection == originIndex) {
                    _lastSuspendHeaderSection = _currSuspendHeaderSection;
                    _currSuspendHeaderSection = NSNotFound;
                }
            } else {
                if (_lastSuspendFooterSection == NSNotFound && _currSuspendFooterSection == originIndex) {
                    _lastSuspendFooterSection = _currSuspendFooterSection;
                    _currSuspendFooterSection = NSNotFound;
                }
            }
            
            if ([self _needPrepareToSuspendViewAt:section withType:type]) {
                frame = [self _prepareToSuspendViewFrameAt:section withType:type];
            }
        }
    }
    
    if (!sectionView) {
        indexPath.section = currIndex;
        
        if (![self _updateNeedToAdjustingBegin:frame.origin.y - sectionOffset andEnd:CGRectGetMaxY(frame) - sectionOffset withOffset:sectionOffset]) {
            return ;
        } else {
            if (type == MPSectionTypeHeader && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
                sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
            } else if (type == MPSectionTypeFooter && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
                sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
            }
            
            if (!sectionView) {
                sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
            } else {
                [_estimatedSectionViewsDic removeObjectForKey:indexPath];
            }
            
            if (!sectionView) {
                return;
            }
            
            CGFloat currOriginY = frame.origin.y;
            CGFloat currHeight = frame.size.height;
            frame.origin.y -= sectionOffset;
            frame.size.height = originHeight;
            sectionView.frame = frame;
            frame.origin.y = currOriginY;
            frame.size.height = currHeight;
            
            if (type == MPSectionTypeHeader) {
                if (_respond_willDisplayHeaderViewForSection) {
                    [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
                }
            } else {
                if (_respond_willDisplayFooterViewForSection) {
                    [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
                }
            }
            
            [self _addSubviewIfNecessaryForSectionView:sectionView];
            [_insertSectionViewsDic setObject:sectionView forKey:indexPath];
            
            void (^animationBlock)(void) = ^{
                sectionView.frame = frame;
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
        }
    } else {
        if (originIndex != currIndex) {
            [_displayedSectionViewsDic removeObjectForKey:indexPath];
            indexPath.section = currIndex;
            [_insertSectionViewsDic setObject:sectionView forKey:indexPath];
        }
        
        void (^animationBlock)(void) = ^{
            sectionView.frame = frame;
        };
        
        [_updateAnimationBlocks addObject:animationBlock];
    }
}

- (BOOL)__updateAdjustSectionViewAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex withType:(MPSectionType)type {
    if (_updateExchangedOffscreenIndexPaths.count) {
        MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:originIndex];
        if ([_updateExchangedOffscreenIndexPaths containsObject:indexPath]) {
            [_updateExchangedOffscreenIndexPaths removeObject:indexPath];
            return YES;
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

#pragma mark - estimated layout

- (BOOL)__isEstimatedMode {
    return _respond_estimatedHeightForRowAtIndexPath || _respond_estimatedHeightForHeaderInSection || _respond_estimatedHeightForFooterInSection;
}

- (BOOL)__estimatedNeedToAdjustAt:(MPTableViewSection *)section withOffset:(CGFloat)offset {
    if (_updateExchangedOffscreenIndexPaths.count) {
        for (MPIndexPath *indexPath in _updateExchangedOffscreenIndexPaths) {
            if (indexPath.section == section.section) {
                return YES;
            }
        }
    }
    
    return !((section.section < _beginIndexPath.section || section.section > _endIndexPath.section) && (section.beginPos + offset > _currDrawArea.endPos || section.endPos + offset < _currDrawArea.beginPos));
}

- (void)_startEstimatedUpdateAtFirstIndexPath:(MPIndexPathStruct)firstIndexPath {
    _lastSuspendFooterSection = _lastSuspendHeaderSection = NSNotFound;
    
    CGFloat offset = [[self _mpEstimatedUpdateManager] startUpdate:firstIndexPath];
    
    _contentDrawArea.endPos += offset;
    
    if (_contentDrawArea.beginPos >= _contentDrawArea.endPos) {
        _beginIndexPath = MPIndexPathStructMake(NSIntegerMax, MPSectionTypeFooter);
        _endIndexPath = MPIndexPathStructMake(NSIntegerMin, MPSectionTypeHeader);
    } else {
        _beginIndexPath = [self _indexPathAtContentOffset:_currDrawArea.beginPos];
        _endIndexPath = [self _indexPathAtContentOffset:_currDrawArea.endPos];
    }
    
    if (_estimatedCellsDic.count) {
        for (MPTableViewCell *cell in _estimatedCellsDic.allValues) {
            [self _cacheCell:cell];
        }
        [_estimatedCellsDic removeAllObjects];
    }
    
    if (_estimatedSectionViewsDic.count) {
        for (MPTableReusableView *view in _estimatedSectionViewsDic.allValues) {
            [self _cacheSectionView:view];
        }
        [_estimatedSectionViewsDic removeAllObjects];
    }
    
    // clip...
    [self _clipCellsBetween:_beginIndexPath and:_endIndexPath];
    
    [self _clipAndAdjustSectionViewsBetween:_beginIndexPath and:_endIndexPath];
    
    if (offset != 0 && self.tableFooterView) {
        CGRect frame = self.tableFooterView.frame;
        frame.origin.y += offset;
        self.tableFooterView.frame = frame;
    }
    
    CGSize contentSize = CGSizeMake(self.bounds.size.width, _contentDrawArea.endPos + self.tableFooterView.frame.size.height);
    if (!CGSizeEqualToSize(self.contentSize, contentSize)) {
        [self setContentSize:contentSize];
        
        // Change a scrollview's content size when it is bouncing will make -layoutSubviews not be called in the next runloop. This situation is possibly caused by an UIKit bug.
        if (_contentOffset.beginPos < -[self _contentInset].top || _contentOffset.beginPos > self.contentSize.height - self.bounds.size.height + [self _contentInset].bottom) {
            CFRunLoopRef runLoop = CFRunLoopGetCurrent();
            CFStringRef runLoopMode = kCFRunLoopCommonModes;
            CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, false, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
                [self layoutSubviews];
            });
            CFRunLoopAddObserver(runLoop, observer, runLoopMode);
            CFRelease(observer);
        }
    }
}

- (CGFloat)__estimateAdjustSectionViewHeight:(MPSectionType)type inSection:(MPTableViewSection *)section {
    if (_contentOffsetChanged) {
        return -1;
    }
    
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:[MPIndexPath indexPathForRow:type inSection:section.section]];
    if (sectionView) {
        return -1;
    }
    
    if ([self _updateSectionViewNeedDisplayAt:section andType:type withOffset:0]) {
        if (type == MPSectionTypeHeader) {
            if (_respond_heightForHeaderInSection) {
                return [_mpDataSource MPTableView:self heightForHeaderInSection:section.section];
            } else if (_respond_estimatedHeightForHeaderInSection) {
                return [self _updateLayoutSizeForSectionViewAtSection:section.section withType:MPSectionTypeHeader baseHeight:-1 withOffset:0];
            }
        } else {
            if (_respond_heightForFooterInSection) {
                return [_mpDataSource MPTableView:self heightForFooterInSection:section.section];
            } else if (_respond_estimatedHeightForFooterInSection) {
                return [self _updateLayoutSizeForSectionViewAtSection:section.section withType:MPSectionTypeFooter baseHeight:-1 withOffset:0];
            }
        }
    }
    
    return -1;
}

- (CGFloat)__estimateAdjustCellAtSection:(NSInteger)originSection atIndex:(NSInteger)originIndex withOffset:(CGFloat)cellOffset {
    CGFloat newOffset = 0;
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:originIndex inSection:originSection];
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    
    if (!cell) {
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        if (MPTableView_Offscreen) {
            if (frame.origin.y > _contentOffset.endPos) {
                return _updateExchangedOffscreenIndexPaths.count ? 0 : MPTableViewMaxSize;
            } else {
                return 0;
            }
        } else {
            cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            
            if (_respond_estimatedHeightForRowAtIndexPath && !_contentOffsetChanged) {
                CGFloat cellHeight = frame.size.height;
                if (_respond_heightForRowAtIndexPath) {
                    frame.size.height = [_mpDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
                } else {
                    frame.size.height = _MP_UpdateLayoutSizeForCell(cell, frame.size.width);
                    if (MPTableView_Offscreen) {
                        [self _cacheCell:cell];
                        return frame.size.height - cellHeight;
                    }
                }
                newOffset = frame.size.height - cellHeight;
            }
            
            _UIFrameWithoutAnimation(cell, frame);
            
            if (_respond_willDisplayCellForRowAtIndexPath) {
                [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
            }
            
            if ([_selectedIndexPaths containsObject:indexPath]) {
                [cell setSelected:YES];
            }
            
            [self _addSubviewIfNecessaryForCell:cell];
            [_displayedCellsDic setObject:cell forKey:indexPath];
        }
    } else {
        if (cellOffset != 0 && cell != _movingDraggedCell) {
            CGRect frame = cell.frame;
            frame.origin.y += cellOffset;
            _UIFrameWithoutAnimation(cell, frame);
        }
    }
    
    return newOffset;
}

- (void)__estimateAdjustSectionViewAtSection:(NSInteger)index withType:(MPSectionType)type {
    
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:index];
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    if (sectionView) {
        return;
    }
    
    BOOL isSuspending = NO;
    BOOL isPrepareToSuspend = NO;
    
    if (self.style == MPTableViewStylePlain) {
        MPTableViewSection *section = _sectionsAreaList[index];
        if ([self _needSuspendingSection:section withType:type]) {
            isSuspending = YES;
        } else {
            if ([self _needPrepareToSuspendViewAt:section withType:type]) {
                isPrepareToSuspend = YES;
            }
        }
    }
    
    CGRect frame = [self _sectionViewFrameAtIndexPath:indexPath];
    if (MPTableView_Offscreen && !isSuspending && !isPrepareToSuspend) {
        return;
    } else {
        if (type == MPSectionTypeHeader && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        } else if (type == MPSectionTypeFooter && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        }
        
        if (!sectionView) {
            sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
        } else {
            [_estimatedSectionViewsDic removeObjectForKey:indexPath];
        }
        
        if (!sectionView) {
            return;
        }
        
        if (_contentOffsetChanged) {
            if (isSuspending) {
                frame = [self _suspendingFrameInSection:_sectionsAreaList[indexPath.section] type:indexPath.row];
            } else if (isPrepareToSuspend) {
                frame = [self _prepareToSuspendViewFrameAt:_sectionsAreaList[indexPath.section] withType:indexPath.row];
            }
        }
        
        _UIFrameWithoutAnimation(sectionView, frame);
        
        if (type == MPSectionTypeHeader) {
            if (_respond_willDisplayHeaderViewForSection) {
                [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
            }
        } else {
            if (_respond_willDisplayFooterViewForSection) {
                [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
            }
        }
        
        [self _addSubviewIfNecessaryForSectionView:sectionView];
        
        [_displayedSectionViewsDic setObject:sectionView forKey:indexPath];
    }
}

#pragma mark - reload

- (BOOL)isCachesReloadEnabled {
    return _cachesReloadEnabled;
}

//
- (void)_clear {
    [self _lockLayoutSubviews];
    
    _contentDrawArea.beginPos = _contentDrawArea.endPos = 0;
    _previousContentOffset = self.contentOffset.y;
    
    [_selectedIndexPaths removeAllObjects];
    [_prefetchIndexPaths removeAllObjects];
    
    [self _resetContentIndexPaths];
    
    [self _endMovingCellIfNeeded];
    
    if ([self isCachesReloadEnabled]) {
        [self _cacheDisplayingCells];
        [self _cacheDisplayingSectionViews];
    } else {
        [self clearReusableCells];
        [self clearReusableSectionViews];
        
        [self _clearDisplayingCells];
        [self _clearDisplayingSectionViews];
    }
}

- (void)_cacheDisplayingCells {
    NSArray *indexPaths = [_displayedCellsDic.allKeys sortedArrayUsingComparator:^NSComparisonResult(MPIndexPath *obj1, MPIndexPath *obj2) {
        return [obj2 compare:obj1];
    }];
    
    for (MPIndexPath *indexPath in indexPaths) {
        [self _cacheCell:[_displayedCellsDic objectForKey:indexPath]];
    }
    
    [_displayedCellsDic removeAllObjects];
}

- (void)_cacheDisplayingSectionViews {
    NSArray *indexPaths = [_displayedSectionViewsDic.allKeys sortedArrayUsingComparator:^NSComparisonResult(MPIndexPath *obj1, MPIndexPath *obj2) {
        return [obj2 compareRowSection:obj1];
    }];
    
    for (MPIndexPath *indexPath in indexPaths) {
        [self _cacheSectionView:[_displayedSectionViewsDic objectForKey:indexPath]];
    }
    
    [_displayedSectionViewsDic removeAllObjects];
}

- (void)_clearDisplayingCells {
    [_displayedCellsDic.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_displayedCellsDic removeAllObjects];
}

- (void)clearReusableCells {
    for (NSMutableArray *queue in _reusableCellsDic.allValues) {
        [queue makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [queue removeAllObjects];
    }
    [_reusableCellsDic removeAllObjects];
}

- (void)clearReusableSectionViews {
    for (NSMutableArray *queue in _reusableReusableViewsDic.allValues) {
        [queue makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [queue removeAllObjects];
    }
    [_reusableReusableViewsDic removeAllObjects];
}

- (void)_clearDisplayingSectionViews {
    [_displayedSectionViewsDic.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_displayedSectionViewsDic removeAllObjects];
}

- (void)reloadData {
    if ([self _isLayoutSubviewsLock] || _updateDataPreparing) {
        return;
    }
    
    NSParameterAssert([NSThread isMainThread]);
    
    [self _resetMovingLongGestureRecognizer];
    [self _clear];
    
    CGFloat height = 0;
    if (_mpDataSource) {
        height = [self _initializeViewsPositionWithNewSections:nil];
        [self _unlockLayoutSubviews];
    }
    
    [self _setVerticalContentHeight:height];
    
    _reloadDataNeededFlag = NO;
    _reloadDataLayoutNeededFlag = YES;
    [self setNeedsLayout];
}

- (void)_resetMovingLongGestureRecognizer {
    [self _lockLayoutSubviews];
    [self _endMovingCellIfNeeded];
    
    _movingLongGestureRecognizer.enabled = NO;
    _movingLongGestureRecognizer.enabled = _moveModeEnabled;
}

- (void)reloadDataAsyncWithCompletion:(void (^)(void))completion {
    if ([self _isLayoutSubviewsLock]) {
        return;
    }
    
    if (!_mpDataSource) {
        return [self reloadData];
    }
    
    _reloadDataNeededFlag = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *newSections = [[NSMutableArray alloc] init];
        CGFloat height = [self _initializeViewsPositionWithNewSections:newSections];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _resetMovingLongGestureRecognizer];
            [self _clear];
            
            _estimatedUpdateManager.sections = _sectionsAreaList = newSections;
            [self _unlockLayoutSubviews];
            if (height != MPTableViewMaxSize && [self superview]) {
                [self _setVerticalContentHeight:height];
                [self _getDisplayingArea];
                [self _updateDisplayingArea];
            }
            if (completion) {
                completion();
            }
        });
    });
}

- (CGFloat)_initializeSection:(MPTableViewSection *)section withOffset:(CGFloat)step {
    // header
    section.beginPos = step;
    CGFloat height = 0;
    
    if (_respond_estimatedHeightForHeaderInSection) {
        MPTableView_ReloadAsync_Exception
        height = [_mpDataSource MPTableView:self estimatedHeightForHeaderInSection:section.section];
    } else {
        if (_respond_heightForHeaderInSection) {
            MPTableView_ReloadAsync_Exception
            height = [_mpDataSource MPTableView:self heightForHeaderInSection:section.section];
        } else {
            height = self.sectionHeaderHeight;
        }
    }
    
    if (height < 0 || height >= MPTableViewMaxSize) {
        @throw [NSException exceptionWithName:MPTableViewException reason:@"section header height" userInfo:nil];
    }
    
    section.headerHeight = height;
    step += height;
    
    if (_mpDataSource) {
        NSUInteger rowsInSection = [_mpDataSource MPTableView:self numberOfRowsInSection:section.section];
        section.numberOfRows = rowsInSection;
        for (NSInteger j = 0; j < rowsInSection; j++) {
            CGFloat cellHeight;
            if (_respond_estimatedHeightForRowAtIndexPath) {
                MPTableView_ReloadAsync_Exception
                cellHeight = [_mpDataSource MPTableView:self estimatedHeightForRowAtIndexPath:[MPIndexPath indexPathForRow:j inSection:section.section]];
            } else {
                if (_respond_heightForRowAtIndexPath) {
                    MPTableView_ReloadAsync_Exception
                    cellHeight = [_mpDataSource MPTableView:self heightForRowAtIndexPath:[MPIndexPath indexPathForRow:j inSection:section.section]];
                } else {
                    cellHeight = self.rowHeight;
                }
            }
            
            if (cellHeight < 0 || cellHeight >= MPTableViewMaxSize) {
                @throw [NSException exceptionWithName:MPTableViewException reason:@"cell height" userInfo:nil];
            }
            
            [section addRowWithPosition:step += cellHeight];
        }
    }
    // footer
    if (_respond_estimatedHeightForFooterInSection) {
        MPTableView_ReloadAsync_Exception
        height = [_mpDataSource MPTableView:self estimatedHeightForFooterInSection:section.section];
    } else {
        if (_respond_heightForFooterInSection) {
            MPTableView_ReloadAsync_Exception
            height = [_mpDataSource MPTableView:self heightForFooterInSection:section.section];
        } else {
            height = self.sectionFooterHeight;
        }
    }
    
    if (height < 0 || height >= MPTableViewMaxSize) {
        @throw [NSException exceptionWithName:MPTableViewException reason:@"section footer height" userInfo:nil];
    }
    
    section.footerHeight = height;
    step += height;
    
    section.endPos = step;
    return step;
}

- (CGFloat)_initializeViewsPositionWithNewSections:(NSMutableArray *)newSections {
    CGFloat step = 0;
    const NSUInteger sectionsCount = _sectionsAreaList.count;
    MPTableView_ReloadAsync_Exception
    if (_respond_numberOfSectionsInMPTableView) {
        _numberOfSections = [_mpDataSource numberOfSectionsInMPTableView:self];
        NSAssert(_numberOfSections < MPTableViewMaxCount, @"too many sections");
    }
    
    if (sectionsCount > _numberOfSections && !newSections) {
        [_sectionsAreaList removeObjectsInRange:NSMakeRange(_numberOfSections, sectionsCount - _numberOfSections)];
    }
    for (NSInteger i = 0; i < _numberOfSections; i++) {
        MPTableViewSection *section;
        if (i < sectionsCount && !newSections) {
            section = _sectionsAreaList[i];
            [section resetSection];
        } else {
            section = [MPTableViewSection section];
        }
        section.section = i;
        
        step = [self _initializeSection:section withOffset:step];
        if (step == MPTableViewMaxSize) {
            [newSections removeAllObjects];
            break;
        }
        if (i >= sectionsCount && !newSections) {
            [_sectionsAreaList addObject:section];
        }
        if (newSections) {
            [newSections addObject:section];
        }
    }
    return step;
}
// header、footer、contentSize
- (void)_setVerticalContentHeight:(CGFloat)height {
    if (self.tableHeaderView) {
        _contentDrawArea.beginPos = self.tableHeaderView.frame.size.height;
    }
    CGFloat contentSizeHeight = _contentDrawArea.endPos = _contentDrawArea.beginPos + height;
    if (self.tableFooterView) {
        CGRect frame = self.tableFooterView.frame;
        frame.origin.y = _contentDrawArea.endPos;
        self.tableFooterView.frame = frame;
        
        contentSizeHeight += frame.size.height;
    }
    [self setContentSize:CGSizeMake(self.bounds.size.width, contentSizeHeight)];
}

#pragma mark - layoutSubviews

- (BOOL)_isLayoutSubviewsLock {
    return _layoutSubviewsLock;
}

- (void)_lockLayoutSubviews {
    _layoutSubviewsLock = YES;
}

- (void)_unlockLayoutSubviews {
    _layoutSubviewsLock = NO;
}

- (void)_getDisplayingArea {
    _contentOffset.beginPos = self.contentOffset.y;
    _contentOffset.endPos = self.contentOffset.y + self.bounds.size.height;
    
    _currDrawArea.beginPos = _contentOffset.beginPos - _contentDrawArea.beginPos;
    _currDrawArea.endPos = _contentOffset.endPos - _contentDrawArea.beginPos;    
}

- (NSInteger)_sectionIndexAtContentOffset:(CGFloat)target {
    NSInteger __count = _sectionsAreaList.count;
    NSInteger __start = 0;
    NSInteger __end = __count - 1;
    NSInteger __middle = 0;
    while (__start <= __end) {
        __middle = (__start + __end) / 2;
        MPTableViewSection *section = _sectionsAreaList[__middle];
        if (section.endPos < target) {
            __start = __middle + 1;
        } else if (section.beginPos > target) {
            __end = __middle - 1;
        } else {
            return __middle;
        }
    }
    return __count - 1; // floating-point precision, target > _sectionsAreaList.lastObject.endPos
}

- (MPIndexPathStruct)_indexPathAtContentOffset:(CGFloat)target {
    if (target > _contentDrawArea.endPos - _contentDrawArea.beginPos) {
        target = _contentDrawArea.endPos - _contentDrawArea.beginPos;
    }
    if (target < 0) {
        target = 0;
    }
    
    NSInteger sectionIndex = [self _sectionIndexAtContentOffset:target];
    MPTableViewSection *section = _sectionsAreaList[sectionIndex];
    NSInteger row = [section rowAtContentOffset:target];
    return MPIndexPathStructMake(sectionIndex, row);
}

- (void)_addSubviewIfNecessaryForCell:(MPTableViewCell *)cell {
    if ([cell superview] != _contentWrapperView) {
        if (_movingDraggedCell) {
            [_contentWrapperView insertSubview:cell belowSubview:_movingDraggedCell];
        } else {
            [_contentWrapperView addSubview:cell];
        }
    }
}

- (void)_addSubviewIfNecessaryForSectionView:(MPTableReusableView *)sectionView {
    if ([sectionView superview] != self) {
        [self insertSubview:sectionView aboveSubview:_contentWrapperView];
    }
}

- (void)_cacheCell:(MPTableViewCell *)cell {
    if ([cell reuseIdentifier]) {
        [cell prepareForRecovery];
        
        NSMutableArray *queue = [_reusableCellsDic objectForKey:cell.reuseIdentifier];
        if (!queue) {
            queue = [[NSMutableArray alloc] init];
            [_reusableCellsDic setObject:queue forKey:cell.reuseIdentifier];
        }
        [queue addObject:cell];
        
        cell.hidden = YES;
        [cell setHighlighted:NO];
        [cell setSelected:NO];
    } else {
        [cell removeFromSuperview];
    }
}

- (void)_clipCellsBetween:(MPIndexPathStruct)beginIndexPathStruct and:(MPIndexPathStruct)endIndexPathStruct {
    NSArray *indexPaths = _displayedCellsDic.allKeys;
    for (MPIndexPath *indexPath in indexPaths) {
        if ([indexPath compareIndexPathAt:beginIndexPathStruct] == NSOrderedAscending || [indexPath compareIndexPathAt:endIndexPathStruct] == NSOrderedDescending) {
            if (_movingIndexPath) {
                if ([indexPath compareRowSection:_movingIndexPath] == NSOrderedSame) {
                    continue;
                }
            } else {
                if ([self isUpdating]) {
                    [_updateExchangedOffscreenIndexPaths addObject:indexPath];
                    continue;
                }
            }
            
            MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
            
            [self _cacheCell:cell];
            [_displayedCellsDic removeObjectForKey:indexPath];
            
            if (_respond_didEndDisplayingCellForRowAtIndexPath) {
                [_mpDelegate MPTableView:self didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
            }
        }
    }
}

- (void)_cacheSectionView:(MPTableReusableView *)sectionView {
    if ([sectionView reuseIdentifier]) {
        [sectionView prepareForRecovery];
        
        NSMutableArray *queue = [_reusableReusableViewsDic objectForKey:sectionView.reuseIdentifier];
        if (!queue) {
            queue = [[NSMutableArray alloc] init];
            [_reusableReusableViewsDic setObject:queue forKey:sectionView.reuseIdentifier];
        }
        sectionView.hidden = YES;
        [queue addObject:sectionView];
    } else {
        [sectionView removeFromSuperview];
    }
}

- (BOOL)_isSuspendingAtIndexPath:(MPIndexPath *)indexPath {
    if (indexPath.row == MPSectionTypeHeader) {
        return indexPath.section == _currSuspendHeaderSection;
    } else {
        return indexPath.section == _currSuspendFooterSection;
    }
}

- (void)_clipSectionViewsBetween:(MPIndexPathStruct)beginIndexPathStruct and:(MPIndexPathStruct)endIndexPathStruct {
    NSArray *indexPaths = _displayedSectionViewsDic.allKeys;
    
    for (MPIndexPath *indexPath in indexPaths) {
        if ([self _isSuspendingAtIndexPath:indexPath]) {
            continue;
        }

        if (_needPreparationDetected) {
            MPTableViewSection *section = _sectionsAreaList[indexPath.section];
            if ([self _needPrepareToSuspendViewAt:section withType:indexPath.row]) {
                MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                CGRect frame = [self _prepareToSuspendViewFrameAt:section withType:indexPath.row];
                _UIFrameWithoutAnimation(sectionView, frame);
                continue;
            } else {
                if ([indexPath compareIndexPathAt:beginIndexPathStruct] != NSOrderedAscending && [indexPath compareIndexPathAt:endIndexPathStruct] != NSOrderedDescending) {
                    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                    CGRect frame = sectionView.frame;
                    frame.origin.y -= _contentDrawArea.beginPos;
                    if (indexPath.row == MPSectionTypeHeader) {
                        if (frame.origin.y != section.beginPos) {
                            frame.origin.y = section.beginPos + _contentDrawArea.beginPos;
                            _UIFrameWithoutAnimation(sectionView, frame);
                        }
                    } else {
                        if (frame.origin.y != section.endPos - section.footerHeight) {
                            frame.origin.y = section.endPos - section.footerHeight + _contentDrawArea.beginPos;
                            _UIFrameWithoutAnimation(sectionView, frame);
                        }
                    }
                    continue;
                }
            }
        }
        if ([indexPath compareIndexPathAt:beginIndexPathStruct] == NSOrderedAscending || [indexPath compareIndexPathAt:endIndexPathStruct] == NSOrderedDescending) {
            if (!_movingIndexPath && [self isUpdating]) {
                [_updateExchangedOffscreenIndexPaths addObject:indexPath];
                continue;
            }
            
            MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
            [self _cacheSectionView:sectionView];
            [_displayedSectionViewsDic removeObjectForKey:indexPath];
            if (_respond_didEndDisplayingHeaderViewForSection && indexPath.row == MPSectionTypeHeader) {
                [_mpDelegate MPTableView:self didEndDisplayingHeaderView:sectionView forSection:indexPath.section];
            }
            if (_respond_didEndDisplayingFooterViewForSection && indexPath.row == MPSectionTypeFooter) {
                [_mpDelegate MPTableView:self didEndDisplayingFooterView:sectionView forSection:indexPath.section];
            }
        }
    }
}

- (void)_clipAndAdjustSectionViewsBetween:(MPIndexPathStruct)beginIndexPathStruct and:(MPIndexPathStruct)endIndexPathStruct {
    NSArray *indexPaths = _displayedSectionViewsDic.allKeys;
    
    for (MPIndexPath *indexPath in indexPaths) {
        if (self.style == MPTableViewStylePlain) {
            MPTableViewSection *section = _sectionsAreaList[indexPath.section];
            if ([self _needSuspendingSection:section withType:indexPath.row]) {
                MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                CGRect frame = [self _suspendingFrameInSection:section type:indexPath.row];
                if (!CGRectEqualToRect(frame, sectionView.frame)) {
                    _UIFrameWithoutAnimation(sectionView, frame);
                }
                continue;
            }
        }
        
        if (_needPreparationDetected) {
            MPTableViewSection *section = _sectionsAreaList[indexPath.section];
            if ([self _needPrepareToSuspendViewAt:section withType:indexPath.row]) {
                MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                CGRect frame = [self _prepareToSuspendViewFrameAt:section withType:indexPath.row];
                if (!CGRectEqualToRect(frame, sectionView.frame)) {
                    _UIFrameWithoutAnimation(sectionView, frame);
                }
                continue;
            }
        }
        
        if ([indexPath compareIndexPathAt:_beginIndexPath] == NSOrderedAscending || [indexPath compareIndexPathAt:_endIndexPath] == NSOrderedDescending) {
            if (!_movingIndexPath && [self isUpdating]) {
                [_updateExchangedOffscreenIndexPaths addObject:indexPath];
                continue;
            }
            
            MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
            [self _cacheSectionView:sectionView];
            [_displayedSectionViewsDic removeObjectForKey:indexPath];
            
            if (_respond_didEndDisplayingHeaderViewForSection && indexPath.row == MPSectionTypeHeader) {
                [_mpDelegate MPTableView:self didEndDisplayingHeaderView:sectionView forSection:indexPath.section];
            }
            if (_respond_didEndDisplayingFooterViewForSection && indexPath.row == MPSectionTypeFooter) {
                [_mpDelegate MPTableView:self didEndDisplayingFooterView:sectionView forSection:indexPath.section];
            }
        } else { // for real-time updates in grouped style
            MPTableViewSection *section = _sectionsAreaList[indexPath.section];
            MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
            CGRect frame = sectionView.frame;
            
            frame.origin.y -= _contentDrawArea.beginPos;
            if (indexPath.row == MPSectionTypeHeader) {
                if (frame.origin.y != section.beginPos) {
                    frame.origin.y = section.beginPos + _contentDrawArea.beginPos;
                    _UIFrameWithoutAnimation(sectionView, frame);
                }
            } else {
                if (frame.origin.y != section.endPos - section.footerHeight) {
                    frame.origin.y = section.endPos - section.footerHeight + _contentDrawArea.beginPos;
                    _UIFrameWithoutAnimation(sectionView, frame);
                }
            }
        }
    }
}

- (void)_updateDisplayingArea {
    if (_contentDrawArea.beginPos >= _contentDrawArea.endPos) {
        return;
    }
    
    MPIndexPathStruct beginIndexPathStruct = [self _indexPathAtContentOffset:_currDrawArea.beginPos];
    MPIndexPathStruct endIndexPathStruct = [self _indexPathAtContentOffset:_currDrawArea.endPos];
    
    if ([self __isEstimatedMode]) { // estimated update
        _updateDataPreparing = YES;
        
        if (!MPEqualIndexPaths(_beginIndexPath, beginIndexPathStruct) || !MPEqualIndexPaths(_endIndexPath, endIndexPathStruct)) {
            MPIndexPathStruct estimatedFirstIndexPath;
            
            if (MPCompareIndexPath(beginIndexPathStruct, _beginIndexPath) == NSOrderedAscending) {
                estimatedFirstIndexPath = beginIndexPathStruct;
                
                [self _startEstimatedUpdateAtFirstIndexPath:estimatedFirstIndexPath];
            } else if (MPCompareIndexPath(endIndexPathStruct, _endIndexPath) == NSOrderedDescending) {
                if (_endIndexPath.row == MPSectionTypeFooter) {
                    estimatedFirstIndexPath = MPIndexPathStructMake(_endIndexPath.section + 1, MPSectionTypeHeader);
                } else if (_endIndexPath.row == MPSectionTypeHeader) {
                    estimatedFirstIndexPath = MPIndexPathStructMake(_endIndexPath.section, 0);
                } else {
                    estimatedFirstIndexPath = MPIndexPathStructMake(_endIndexPath.section, _endIndexPath.row + 1);
                }
                
                [self _startEstimatedUpdateAtFirstIndexPath:estimatedFirstIndexPath];
            } else {
                [self _clipCellsBetween:beginIndexPathStruct and:endIndexPathStruct];
                [self _clipAndAdjustSectionViewsBetween:beginIndexPathStruct and:endIndexPathStruct];
                
                _beginIndexPath = beginIndexPathStruct;
                _endIndexPath = endIndexPathStruct;
            }
        } else if (self.style == MPTableViewStylePlain) {
            [self _clipAndAdjustSectionViewsBetween:beginIndexPathStruct and:endIndexPathStruct];
        }
        
        _updateDataPreparing = NO;
    } else { // normal update
        _updateDataPreparing = YES;
        
        if (self.style == MPTableViewStylePlain) {
            [self _suspendSectionHeaderIfNeededAt:beginIndexPathStruct];
            [self _suspendSectionFooterIfNeededAt:endIndexPathStruct];
        }
        
        if (!MPEqualIndexPaths(_beginIndexPath, beginIndexPathStruct) || !MPEqualIndexPaths(_endIndexPath, endIndexPathStruct)) {
            [self _clipCellsBetween:beginIndexPathStruct and:endIndexPathStruct];
            [self _clipSectionViewsBetween:beginIndexPathStruct and:endIndexPathStruct];
            
            [self _updateDisplayingBegin:beginIndexPathStruct and:endIndexPathStruct];
        }
        
        _updateDataPreparing = NO;
    }
}

- (void)_updateDisplayingBegin:(MPIndexPathStruct)beginIndexPathStruct and:(MPIndexPathStruct)endIndexPathStruct {
    for (NSInteger i = beginIndexPathStruct.section; i <= endIndexPathStruct.section; i++) {
        MPTableViewSection *section = _sectionsAreaList[i];
        
        NSInteger startCellIndex = 0, endCellIndex = section.numberOfRows;
        BOOL needSectionHeader = YES, needSectionFooter = YES;
        
        if (i == beginIndexPathStruct.section) {
            if (beginIndexPathStruct.row != MPSectionTypeFooter) {
                if (beginIndexPathStruct.section != _currSuspendHeaderSection && [self _needPrepareToSuspendViewAt:section withType:MPSectionTypeHeader]) {
                    [self _makePrepareToSuspendViewInSection:section withType:MPSectionTypeHeader];
                }
            }
            if (beginIndexPathStruct.row == MPSectionTypeHeader) {
                startCellIndex = 0;
            } else {
                startCellIndex = beginIndexPathStruct.row;
                needSectionHeader = NO;
            }
        }
        
        if (i == endIndexPathStruct.section) {
            if (endIndexPathStruct.row != MPSectionTypeHeader) {
                if (endIndexPathStruct.section != _currSuspendFooterSection && [self _needPrepareToSuspendViewAt:section withType:MPSectionTypeFooter]) {
                    [self _makePrepareToSuspendViewInSection:section withType:MPSectionTypeFooter];
                }
            }
            if (endIndexPathStruct.row == MPSectionTypeFooter) {
                endCellIndex = section.numberOfRows;
            } else {
                endCellIndex = endIndexPathStruct.row + 1;
                needSectionFooter = NO;
            }
        }
        
        if (needSectionHeader && section.headerHeight) {
            if ([self _needPrepareToSuspendViewAt:section withType:MPSectionTypeHeader]) {
                [self _makePrepareToSuspendViewInSection:section withType:MPSectionTypeHeader];
            } else {
                [self _displayingSectionViewAtIndexPath:[MPIndexPath indexPathForRow:MPSectionTypeHeader inSection:i]];
            }
        }
        
        if (needSectionFooter && section.footerHeight) {
            if ([self _needPrepareToSuspendViewAt:section withType:MPSectionTypeFooter]) {
                [self _makePrepareToSuspendViewInSection:section withType:MPSectionTypeFooter];
            } else {
                [self _displayingSectionViewAtIndexPath:[MPIndexPath indexPathForRow:MPSectionTypeFooter inSection:i]];
            }
        }
        
        for (NSInteger j = startCellIndex; j < endCellIndex; j++) {
            MPIndexPathStruct indexPath_ = {i, j};
            if (MPCompareIndexPath(indexPath_, _beginIndexPath) == NSOrderedAscending || MPCompareIndexPath(indexPath_, _endIndexPath) == NSOrderedDescending) {
                MPIndexPath *indexPath = [MPIndexPath indexPathFromStruct:indexPath_];
                
                if (([self isUpdating] || [self __isContentMoving]) && [_displayedCellsDic objectForKey:indexPath]) {
                    continue;
                }
                
                MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
                
                if ([_selectedIndexPaths containsObject:indexPath]) {
                    [cell setSelected:YES];
                }
                
                _UIFrameWithoutAnimation(cell, [self _cellFrameAtIndexPath:indexPath]);
                
                if (_respond_willDisplayCellForRowAtIndexPath) {
                    [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
                }
                
                [self _addSubviewIfNecessaryForCell:cell];
                if ([self isUpdating]) {
                    [_contentWrapperView sendSubviewToBack:cell];
                }
                
                [_displayedCellsDic setObject:cell forKey:indexPath];
            }
        }
    }
    
    _beginIndexPath = beginIndexPathStruct;
    _endIndexPath = endIndexPathStruct;
}

- (MPTableViewCell *)_getCellFromDataSourceAtIndexPath:(MPIndexPath *)indexPath {
    MPTableViewCell *cell = [_mpDataSource MPTableView:self cellForRowAtIndexPath:indexPath];
    if (!cell) {
        @throw [NSException exceptionWithName:MPTableViewException reason:@"cell must not be null" userInfo:nil];
    }
    
    return cell;
}

- (CGRect)_cellFrameAtIndexPath:(MPIndexPath *)indexPath {
    if (!indexPath) {
        return CGRectZero;
    }
    MPTableViewSection *section = _sectionsAreaList[indexPath.section];
    CGFloat beginPos = [section rowPositionBeginAt:indexPath.row];
    CGFloat endPos = [section rowPositionEndAt:indexPath.row];
    
    CGRect frame;
    frame.origin.x = 0;
    frame.origin.y = beginPos;
    frame.size.height = endPos - beginPos;
    frame.size.width = self.bounds.size.width;
    frame.origin.y += _contentDrawArea.beginPos;
    return frame;
}

- (MPTableReusableView *)_getSectionViewFromDelegateAtIndexPath:(MPIndexPath *)indexPath {
    MPTableReusableView *sectionView = nil;
    if (indexPath.row == MPSectionTypeHeader) {
        if (_respond_viewForHeaderInSection) {
            sectionView = [_mpDataSource MPTableView:self viewForHeaderInSection:indexPath.section];
        }
    } else {
        if (_respond_viewForFooterInSection) {
            sectionView = [_mpDataSource MPTableView:self viewForFooterInSection:indexPath.section];
        }
    }
    
    return sectionView;
}

- (CGRect)_sectionViewFrameAtIndexPath:(MPIndexPath *)indexPath {
    CGRect sectionViewFrame;
    MPTableViewSection *section = _sectionsAreaList[indexPath.section];
    if (indexPath.row == MPSectionTypeHeader) {
        sectionViewFrame.origin.y = section.beginPos;
        sectionViewFrame.size.height = section.headerHeight;
    } else {
        sectionViewFrame.origin.y = section.endPos - section.footerHeight;
        sectionViewFrame.size.height = section.footerHeight;
    }
    sectionViewFrame.origin.x = 0;
    sectionViewFrame.size.width = self.bounds.size.width;
    sectionViewFrame.origin.y += _contentDrawArea.beginPos;
    
    return sectionViewFrame;
}

- (void)_displayingSectionViewAtIndexPath:(MPIndexPath *)indexPath {
    if (self.style == MPTableViewStylePlain || [self isUpdating]) {
        if (![_displayedSectionViewsDic objectForKey:indexPath]) {
            [self _drawSectionViewAtIndexPath:indexPath];
        }
    } else {
        if ([indexPath compareIndexPathAt:_beginIndexPath] == NSOrderedAscending || [indexPath compareIndexPathAt:_endIndexPath] == NSOrderedDescending) {
            [self _drawSectionViewAtIndexPath:indexPath];
        }
    }
}

- (MPTableReusableView *)_drawSectionViewAtIndexPath:(MPIndexPath *)indexPath {
    MPTableReusableView *sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
    if (sectionView) {
        CGRect frame = [self _sectionViewFrameAtIndexPath:indexPath];
        _UIFrameWithoutAnimation(sectionView, frame);
        
        if (indexPath.row == MPSectionTypeHeader) {
            if (_respond_willDisplayHeaderViewForSection) {
                [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
            }
        } else {
            if (_respond_willDisplayFooterViewForSection) {
                [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
            }
        }
        
        [self _addSubviewIfNecessaryForSectionView:sectionView];
        [_displayedSectionViewsDic setObject:sectionView forKey:indexPath];
    }
    return sectionView;
}

- (BOOL)_needPrepareToSuspendViewAt:(MPTableViewSection *)section withType:(MPSectionType)type {
    if (!_needPreparationDetected) {
        return NO;
    }
    
    if (type == MPSectionTypeHeader) {
        CGFloat contentBegin = _currDrawArea.beginPos + [self _contentInset].top;
        if (section.headerHeight && [self _contentInset].top != 0 && section.endPos <= contentBegin && section.endPos - section.footerHeight > _currDrawArea.beginPos) {
            return YES;
        } else {
            return NO;
        }
    } else {
        CGFloat contentEnd = _currDrawArea.endPos - [self _contentInset].bottom;
        if (section.footerHeight && [self _contentInset].bottom != 0 && section.beginPos >= contentEnd && section.beginPos + section.headerHeight < _currDrawArea.endPos) {
            return YES;
        } else {
            return NO;
        }
    }
}

- (CGRect)_prepareToSuspendViewFrameAt:(MPTableViewSection *)section withType:(MPSectionType)type {
    if (type == MPSectionTypeHeader) {
        return CGRectMake(0, section.endPos - section.footerHeight - section.headerHeight + _contentDrawArea.beginPos, self.bounds.size.width, section.headerHeight);
    } else {
        return CGRectMake(0, section.beginPos + section.headerHeight + _contentDrawArea.beginPos, self.bounds.size.width, section.footerHeight);
    }
}

- (void)_makePrepareToSuspendViewInSection:(MPTableViewSection *)section withType:(MPSectionType)type {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:section.section];
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    
    if (!sectionView) {
        sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
        
        if (sectionView) {
            if (type == MPSectionTypeHeader) {
                if (_respond_willDisplayHeaderViewForSection) {
                    [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
                }
            } else {
                if (_respond_willDisplayFooterViewForSection) {
                    [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
                }
            }
            
            [self _addSubviewIfNecessaryForSectionView:sectionView];
            [_displayedSectionViewsDic setObject:sectionView forKey:indexPath];
        } else {
            return;
        }
    } else {
        if (_contentOffsetChanged) {
            return;
        }
    }
    
    CGRect frame = [self _prepareToSuspendViewFrameAt:section withType:type];
    if (!CGRectEqualToRect(frame, sectionView.frame)) {
        _UIFrameWithoutAnimation(sectionView, frame);
    }
}

- (void)_suspendSectionHeaderIfNeededAt:(MPIndexPathStruct) beginIndexPath {
    MPTableViewSection *section;
    if ([self _contentInset].top != 0) {
        CGFloat target = _currDrawArea.beginPos + [self _contentInset].top;
        if (target > _contentDrawArea.endPos - _contentDrawArea.beginPos) {
            target = _contentDrawArea.endPos - _contentDrawArea.beginPos;
        }
        if (target < 0) {
            target = 0;
        }
        section = _sectionsAreaList[[self _sectionIndexAtContentOffset:target]];
    } else {
        section = _sectionsAreaList[beginIndexPath.section];
    }
    if (section.headerHeight) {
        BOOL isResetPreSuspend;
        if ([self _contentInset].top != 0) {
            isResetPreSuspend = YES;
        } else {
            isResetPreSuspend = beginIndexPath.row != MPSectionTypeFooter;
        }
        if (_currSuspendHeaderSection != section.section && isResetPreSuspend) {
            beginIndexPath.row = MPSectionTypeHeader;
            MPIndexPath *indexPath = [MPIndexPath indexPathForRow:MPSectionTypeHeader inSection:_currSuspendHeaderSection];
            _currSuspendHeaderSection = section.section;
            UIView *lastSuspendHeader = [_displayedSectionViewsDic objectForKey:indexPath];
            if (lastSuspendHeader) {
                MPTableViewSection *lastSection = _sectionsAreaList[indexPath.section];
                CGRect frame = lastSuspendHeader.frame;
                if ([self _needPrepareToSuspendViewAt:lastSection withType:MPSectionTypeHeader]) { // prepare suspending
                    frame.origin.y = lastSection.endPos - lastSection.footerHeight - lastSection.headerHeight;
                } else {
                    frame.origin.y = lastSection.beginPos;
                }
                frame.origin.y += _contentDrawArea.beginPos;
                _UIFrameWithoutAnimation(lastSuspendHeader, frame);
            }
        } else if (_currSuspendHeaderSection != NSNotFound) {
            section = _sectionsAreaList[_currSuspendHeaderSection];
        } else {
            return;
        }
        
        if (section.endPos - section.footerHeight < _currDrawArea.beginPos) {
            return;
        }
        
        MPIndexPath *indexPath = [MPIndexPath indexPathForRow:MPSectionTypeHeader inSection:_currSuspendHeaderSection];
        UIView *suspendHeader = [_displayedSectionViewsDic objectForKey:indexPath];
        if (!suspendHeader) {
            suspendHeader = [self _drawSectionViewAtIndexPath:indexPath];
        }
        
        CGRect frame = [self _suspendingFrameInSection:section type:MPSectionTypeHeader];
        if (!CGRectEqualToRect(frame, suspendHeader.frame)) {
            _UIFrameWithoutAnimation(suspendHeader, frame);
        }
    }
}

- (CGRect)_suspendingFrameInSection:(MPTableViewSection *)section type:(MPSectionType)type {
    CGRect frame;
    frame.origin.x = 0;
    frame.size.width = self.bounds.size.width;
    if (type == MPSectionTypeHeader) {
        frame.size.height = section.headerHeight;
        
        frame.origin.y = _currDrawArea.beginPos + [self _contentInset].top;
        if (CGRectGetMaxY(frame) > section.endPos - section.footerHeight) {
            if (frame.origin.y != section.endPos - section.footerHeight - frame.size.height) {
                frame.origin.y = section.endPos - section.footerHeight - frame.size.height;
            }
        }
        if (frame.origin.y < section.beginPos) {
            if (frame.origin.y != section.beginPos) {
                frame.origin.y = section.beginPos;
            }
        }
        
        frame.origin.y += _contentDrawArea.beginPos;
    } else {
        frame.size.height = section.footerHeight;
        
        frame.origin.y = _currDrawArea.endPos - frame.size.height - [self _contentInset].bottom;
        if (frame.origin.y < section.beginPos + section.headerHeight) {
            if (frame.origin.y != section.beginPos + section.headerHeight) {
                frame.origin.y = section.beginPos + section.headerHeight;
            }
        }
        if (CGRectGetMaxY(frame) > section.endPos) {
            if (frame.origin.y != section.endPos - section.footerHeight) {
                frame.origin.y = section.endPos - section.footerHeight;
            }
        }
        
        frame.origin.y += _contentDrawArea.beginPos;
    }
    
    return frame;
}

- (void)_suspendSectionFooterIfNeededAt:(MPIndexPathStruct)endIndexPath {
    MPTableViewSection *section;
    if ([self _contentInset].bottom != 0) {
        CGFloat target = _currDrawArea.endPos - [self _contentInset].bottom;
        if (target > _contentDrawArea.endPos - _contentDrawArea.beginPos) {
            target = _contentDrawArea.endPos - _contentDrawArea.beginPos;
        }
        section = _sectionsAreaList[[self _sectionIndexAtContentOffset:target]];
    } else {
        section = _sectionsAreaList[endIndexPath.section];
    }
    if (section.footerHeight) {
        BOOL isResetPreSuspend;
        if ([self _contentInset].bottom != 0) {
            isResetPreSuspend = YES;
        } else {
            isResetPreSuspend = endIndexPath.row != MPSectionTypeHeader;
        }
        if (_currSuspendFooterSection != section.section && isResetPreSuspend) {
            endIndexPath.row = MPSectionTypeFooter;
            MPIndexPath *indexPath = [MPIndexPath indexPathForRow:MPSectionTypeFooter inSection:_currSuspendFooterSection];
            _currSuspendFooterSection = section.section;
            UIView *lastSuspendFooter = [_displayedSectionViewsDic objectForKey:indexPath];
            if (lastSuspendFooter) {
                MPTableViewSection *lastSection = _sectionsAreaList[indexPath.section];
                CGRect frame = lastSuspendFooter.frame;
                if ([self _needPrepareToSuspendViewAt:lastSection withType:MPSectionTypeFooter]) {
                    frame.origin.y = lastSection.beginPos + lastSection.headerHeight;
                } else {
                    frame.origin.y = lastSection.endPos - lastSection.footerHeight;
                }
                frame.origin.y += _contentDrawArea.beginPos;
                _UIFrameWithoutAnimation(lastSuspendFooter, frame);
            }
        } else if (_currSuspendFooterSection != NSNotFound) {
            section = _sectionsAreaList[_currSuspendFooterSection];
        } else {
            return;
        }
        if (section.beginPos + section.headerHeight > _currDrawArea.endPos) {
            return;
        }
        
        MPIndexPath *indexPath = [MPIndexPath indexPathForRow:MPSectionTypeFooter inSection:_currSuspendFooterSection];
        UIView *suspendFooter = [_displayedSectionViewsDic objectForKey:indexPath];
        if (!suspendFooter) {
            suspendFooter = [self _drawSectionViewAtIndexPath:indexPath];
        }
        
        CGRect frame = [self _suspendingFrameInSection:section type:MPSectionTypeFooter];
        if (!CGRectEqualToRect(frame, suspendFooter.frame)) {
            _UIFrameWithoutAnimation(suspendFooter, frame);
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (![self _isLayoutSubviewsLock]) {
        if (!_mpDataSource) {
            [self _respondsToDataSource];
            return [self _clear];
        }
        
        [self _getDisplayingArea];
        
        if (_reloadDataNeededFlag) {
            [self reloadData];
            if (!_numberOfSections) {
                return;
            }
        }
        [self _lockLayoutSubviews];
        
        [self _updateDisplayingArea];
        
        [self _prefetchDataIfNeeded];
        
        [self _unlockLayoutSubviews];
        
        _reloadDataLayoutNeededFlag = NO;
    }
    
    [self _layoutBackgroundViewIfNeeded];
}

#pragma mark - prefetch

- (void)_prefetchDataIfNeeded {
    if (!_prefetchDataSource || !_numberOfSections || _beginIndexPath.section == NSIntegerMax || _endIndexPath.section == NSIntegerMin) {
        return;
    }
    
    MPIndexPath *beginIndexPath = [self beginIndexPath];
    MPIndexPath *endIndexPath = [self endIndexPath];
    
    BOOL scrollDirectionUp = _contentOffset.beginPos < _previousContentOffset;
    
    @autoreleasepool {
        NSMutableArray *prefetchUpIndexPaths = [[NSMutableArray alloc] init];
        NSMutableArray *prefetchDownIndexPaths = [[NSMutableArray alloc] init];
        
        MPIndexPath *prefetchBeginIndexPath = [beginIndexPath copy];
        for (NSInteger i = 0; i < 15; i++) {
            if (prefetchBeginIndexPath.row > 0) {
                --prefetchBeginIndexPath.row;
            } else {
                while (prefetchBeginIndexPath.section > 0) {
                    MPTableViewSection *section = _sectionsAreaList[--prefetchBeginIndexPath.section];
                    if (section.numberOfRows > 0) {
                        prefetchBeginIndexPath.row = section.numberOfRows - 1;
                        goto ADD_UP_INDEXPATH;
                    }
                }
                break;
            }
            
        ADD_UP_INDEXPATH:
            if (i < 10 && scrollDirectionUp) {
                MPIndexPath *indexPath = [prefetchBeginIndexPath copy];
                if (![_prefetchIndexPaths containsObject:indexPath]) {
                    [prefetchUpIndexPaths addObject:indexPath];
                }
            }
        }
        
        MPIndexPath *prefetchEndIndexPath = [endIndexPath copy];
        NSUInteger numberOfSections = _sectionsAreaList.count;
        
        for (NSInteger i = 0; i < 15; i++) {
            MPTableViewSection *section = _sectionsAreaList[prefetchEndIndexPath.section];
            if (prefetchEndIndexPath.row + 1 < section.numberOfRows) {
                ++prefetchEndIndexPath.row;
            } else {
                while (prefetchEndIndexPath.section + 1 < numberOfSections) {
                    section = _sectionsAreaList[++prefetchEndIndexPath.section];
                    if (section.numberOfRows > 0) {
                        prefetchEndIndexPath.row = 0;
                        goto ADD_DOWN_INDEXPATH;
                    }
                }
                break;
            }
            
        ADD_DOWN_INDEXPATH:
            if (i < 10 && !scrollDirectionUp) {
                MPIndexPath *indexPath = [prefetchEndIndexPath copy];
                if (![_prefetchIndexPaths containsObject:indexPath]) {
                    [prefetchDownIndexPaths addObject:indexPath];
                }
            }
        }
        
        if (prefetchUpIndexPaths.count || prefetchDownIndexPaths.count) {
            
            [prefetchUpIndexPaths addObjectsFromArray:prefetchDownIndexPaths];
            [_prefetchIndexPaths addObjectsFromArray:prefetchUpIndexPaths];
            
            [_prefetchDataSource MPTableView:self prefetchRowsAtIndexPaths:prefetchUpIndexPaths];
        }
        
        NSMutableArray *discardIndexPaths = [[NSMutableArray alloc] init];
        NSMutableArray *cancelPrefetchIndexPaths = [[NSMutableArray alloc] init];
        for (MPIndexPath *indexPath in _prefetchIndexPaths) {
            if ([indexPath compareRowSection:beginIndexPath] != NSOrderedAscending && [indexPath compareRowSection:endIndexPath] != NSOrderedDescending) {
                [discardIndexPaths addObject:indexPath];
            } else if ([indexPath compareRowSection:prefetchBeginIndexPath] == NSOrderedAscending || [indexPath compareRowSection:prefetchEndIndexPath] == NSOrderedDescending) {
                [cancelPrefetchIndexPaths addObject:indexPath];
            }
        }
        
        [_prefetchIndexPaths removeObjectsInArray:discardIndexPaths];
        [_prefetchIndexPaths removeObjectsInArray:cancelPrefetchIndexPaths];
        
        if (_respond_cancelPrefetchingForRowsAtIndexPaths && cancelPrefetchIndexPaths.count) {
            [_prefetchDataSource MPTableView:self cancelPrefetchingForRowsAtIndexPaths:cancelPrefetchIndexPaths];
        }
    }
    
    _previousContentOffset = _contentOffset.beginPos;
}

#pragma mark - select

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    if (_highlightedIndexPath || _movingIndexPath) {
        return;
    }
    
    if ([self isDecelerating] || [self isDragging] || _contentDrawArea.beginPos >= _contentDrawArea.endPos) {
        return;
    }
    
    // row selected
    UITouch *touch = touches.anyObject;
    CGPoint location = [touch locationInView:self];
    CGFloat touchPosition = location.y;
    if (_allowsSelection && touchPosition >= _contentDrawArea.beginPos && touchPosition <= _contentDrawArea.endPos) {
        
        MPIndexPath *touchedIndexPath = [MPIndexPath indexPathFromStruct:[self _indexPathAtContentOffset:touchPosition - _contentDrawArea.beginPos]];
        
        if (touchedIndexPath.row == MPSectionTypeHeader || touchedIndexPath.row == MPSectionTypeFooter) {
            return;
        }
        
        MPTableViewCell *cell = [_displayedCellsDic objectForKey:touchedIndexPath];
        if (!cell) {
            return;
        }
        
        if (_moveModeEnabled) {
            if (_allowsSelectionDuringMoving) {
                 // If the rect for start moving in cell is not specified, this selection is depending on whether the _allowsSelectionDuringMoving is YES
                if (_respond_rectForCellToMoveRowAtIndexPath && [self _rectForCell:cell toMoveRowAtIndexPath:touchedIndexPath availableInLocation:location]) {
                    return;
                }
            } else {
                return;
            }
        }
        
        if (_respond_shouldHighlightRowAtIndexPath && ![_mpDelegate MPTableView:self shouldHighlightRowAtIndexPath:touchedIndexPath]) {
            return;
        }
        
        _highlightedIndexPath = touchedIndexPath;
        
        if (![cell isHighlighted]) {
            [cell setHighlighted:YES];
        }
        
        if (_respond_didHighlightRowAtIndexPath) {
            [_mpDelegate MPTableView:self didHighlightRowAtIndexPath:touchedIndexPath];
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    
    [self _unhighlightedCellIfNeeded];
}

- (void)_unhighlightedCellIfNeeded {
    if (_highlightedIndexPath) {
        MPTableViewCell *cell = [_displayedCellsDic objectForKey:_highlightedIndexPath];
        
        if ([cell isHighlighted]) {
            [cell setHighlighted:NO];
        }
        
        if (_respond_didUnhighlightRowAtIndexPath) {
            [_mpDelegate MPTableView:self didUnhighlightRowAtIndexPath:[_highlightedIndexPath copy]];
        }
        
        _highlightedIndexPath = nil;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    
    if (_highlightedIndexPath && _allowsSelection) {
        MPTableViewCell *cell = [_displayedCellsDic objectForKey:_highlightedIndexPath];
        if (!cell) {
            _highlightedIndexPath = nil;
            return;
        }
        MPTableViewCell *highlightedCell = cell;
        
        if (_respond_willSelectRowForCellAtIndexPath) {
            MPIndexPath *indexPath = [_mpDelegate MPTableView:self willSelectRowForCell:cell atIndexPath:[_highlightedIndexPath copy]];
            if (!indexPath) {
                goto UNHIGHLIGHT;
            }
            
            if (![_highlightedIndexPath isEqual:indexPath]) {
                cell = [_displayedCellsDic objectForKey:_highlightedIndexPath = [indexPath copy]];
            }
        }
        
        if (_allowsMultipleSelection && [_selectedIndexPaths containsObject:_highlightedIndexPath]) {
            [self _deselectRowAtIndexPath:_highlightedIndexPath animated:NO selectedIndexPathRemove:YES];
        } else {
            if (!_allowsMultipleSelection && ![_selectedIndexPaths containsObject:_highlightedIndexPath]) {
                [self _deselectRowAtIndexPath:_selectedIndexPaths.anyObject animated:NO selectedIndexPathRemove:YES];
            }
            
            [_selectedIndexPaths addObject:_highlightedIndexPath];
            
            [cell setSelected:YES];
            
            if (_respond_didSelectRowForCellAtIndexPath) {
                [_mpDelegate MPTableView:self didSelectRowForCell:cell atIndexPath:[_highlightedIndexPath copy]];
            }
        }
        
    UNHIGHLIGHT:
        if ([highlightedCell isHighlighted]) {
            [highlightedCell setHighlighted:NO];
        }
        
        if (_respond_didUnhighlightRowAtIndexPath) {
            [_mpDelegate MPTableView:self didUnhighlightRowAtIndexPath:[_highlightedIndexPath copy]];
        }
        
        _highlightedIndexPath = nil;
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    
    [self _unhighlightedCellIfNeeded];
}

#pragma mark - move

NS_INLINE CGPoint MPPointsSubtraction(CGPoint point1, CGPoint point2) {
    return CGPointMake(point1.x - point2.x, point1.y - point2.y);
}

//NS_INLINE CGPoint MPPointsAddition(CGPoint point1, CGPoint point2) {
//    return CGPointMake(point1.x + point2.x, point1.y + point2.y);
//}

- (MPIndexPath *)movingIndexPath {
    return [_movingIndexPath copy];
}

- (BOOL)__isContentMoving {
    return _movingIndexPath ? YES : NO;
}

- (BOOL)isMoveModeEnabled {
    return _moveModeEnabled;
}

- (void)setMoveModeEnabled:(BOOL)moveModeEnabled {
    if (_moveModeEnabled && !moveModeEnabled) {
        [self _endMovingCellIfNeeded];
    }
    
    [self _setupMovingLongGestureRecognizerIfNeeded];
    _movingLongGestureRecognizer.enabled = moveModeEnabled;
    
    _moveModeEnabled = moveModeEnabled;
}

- (void)_setupMovingLongGestureRecognizerIfNeeded {
    if (!_movingLongGestureRecognizer) {
        _movingLongGestureRecognizer = [[MPTableViewLongGestureRecognizer alloc] initWithTarget:self action:@selector(_movingPanGestureRecognizerAction:)];
        _movingLongGestureRecognizer.tableView = self;
        [_contentWrapperView addGestureRecognizer:_movingLongGestureRecognizer];
    }
}

- (void)setMinimumPressDurationForMovement:(CFTimeInterval)minimumPressDurationForMovement {
    [self _setupMovingLongGestureRecognizerIfNeeded];
    _movingLongGestureRecognizer.minimumPressDuration = _minimumPressDurationForMovement = minimumPressDurationForMovement;
}

- (BOOL)mp_gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([self isUpdating]) {
        return NO;
    }
    
    CGPoint location = [gestureRecognizer locationInView:_contentWrapperView];
    [self _beginMovingCellInLocation:location];
    
    return _movingIndexPath ? YES : NO;
}

- (void)_movingPanGestureRecognizerAction:(UIPanGestureRecognizer *)panGestureRecognizer {
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan: {
            
        }
            break;
        case UIGestureRecognizerStateChanged: {
            CGPoint location = [panGestureRecognizer locationInView:_contentWrapperView];
            [self _movingCellToLocation:location];
        }
            break;
        case UIGestureRecognizerStateEnded: {
            [self _endMovingCellIfNeeded];
        }
            break;
        case UIGestureRecognizerStateCancelled: {
            [self _endMovingCellIfNeeded];
        }
            break;
        case UIGestureRecognizerStateFailed: {
            [self _endMovingCellIfNeeded];
        }
            break;
        default:
            [self _endMovingCellIfNeeded];
            break;
    }
}

- (void)_beginMovingCellInLocation:(CGPoint)location {
    [self _endMovingCellIfNeeded];
    
    CGFloat touchPosition = location.y;
    if (touchPosition >= _contentDrawArea.beginPos && touchPosition <= _contentDrawArea.endPos) {
        
        MPIndexPath *touchedIndexPath = [MPIndexPath indexPathFromStruct:[self _indexPathAtContentOffset:touchPosition - _contentDrawArea.beginPos]];
        if (touchedIndexPath.row == MPSectionTypeHeader || touchedIndexPath.row == MPSectionTypeFooter) {
            return;
        }
        
        [self _lockLayoutSubviews];
        
        MPTableViewCell *cell = [_displayedCellsDic objectForKey:touchedIndexPath];
        
        if (_respond_canMoveRowAtIndexPath && ![_mpDataSource MPTableView:self canMoveRowAtIndexPath:touchedIndexPath]) {
            goto UNLOCK_LAYOUTSUBVIEWS_MOVE;
        }
        
        if (_respond_rectForCellToMoveRowAtIndexPath && ![self _rectForCell:cell toMoveRowAtIndexPath:touchedIndexPath availableInLocation:location]) {
            goto UNLOCK_LAYOUTSUBVIEWS_MOVE;
        }
        
        _movingDraggedCell = cell;
        _sourceIndexPath = _movingIndexPath = touchedIndexPath;
        _movingMinuendPoint = MPPointsSubtraction(location, _movingDraggedCell.center);
        
        if (_respond_shouldMoveRowAtIndexPath) {
            [_mpDelegate MPTableView:self shouldMoveRowAtIndexPath:touchedIndexPath];
        }
        
        [_contentWrapperView bringSubviewToFront:_movingDraggedCell];
        
        [self _setupMovingScrollDisplayLinkIfNeeded];
        
    UNLOCK_LAYOUTSUBVIEWS_MOVE:
        [self _unlockLayoutSubviews];
    }
}

- (BOOL)_rectForCell:(MPTableViewCell *)cell toMoveRowAtIndexPath:(MPIndexPath *)indexPath availableInLocation:(CGPoint)location {
    CGRect touchEnabledFrame = [_mpDataSource MPTableView:self rectForCellToMoveRowAtIndexPath:indexPath];
    
    return CGRectContainsPoint(touchEnabledFrame, [cell convertPoint:location fromView:_contentWrapperView]);
}

- (void)_setupMovingScrollDisplayLinkIfNeeded {
    if (!_movingScrollDisplayLink) {
        _movingScrollDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_boundsScrollingAction)];
        [_movingScrollDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    [self _boundsScrollingIfNeeded];
}

- (void)_movingCellToLocation:(CGPoint)location {
    [self _movingCellSetCenter:MPPointsSubtraction(location, _movingMinuendPoint)];
    
    [self _boundsScrollingIfNeeded];
    
    [self _getDisplayingArea];
    [self _updateDisplayingArea];
    
    location = _movingDraggedCell.center;
    [self _movingCellToUpdateInPosition:location.y];
}

- (void)_movingCellSetCenter:(CGPoint)center {
    if (!_allowsDragCellOut) {
        center.x = self.bounds.size.width / 2;
        if (center.y < _contentDrawArea.beginPos) {
            center.y = _contentDrawArea.beginPos;
        }
        if (center.y > _contentDrawArea.endPos) {
            center.y = _contentDrawArea.endPos;
        }
    }
    
    _movingDraggedCell.center = center;
}

- (void)_boundsScrollingAction {
    CGPoint newPoint = self.contentOffset;
    newPoint.y += _movingScrollFate;
    
    if (_movingScrollFate < 0) {
        if (newPoint.y < -[self _contentInset].top) {
            newPoint.y = -[self _contentInset].top;
            _movingScrollDisplayLink.paused = YES;
        }
    } else if (_movingScrollFate > 0) {
        if (newPoint.y + self.bounds.size.height > self.contentSize.height + [self _contentInset].bottom) {
            newPoint.y = self.contentSize.height + [self _contentInset].bottom - self.bounds.size.height;
            _movingScrollDisplayLink.paused = YES;
        }
    }
    
    self.contentOffset = newPoint;
    
    newPoint.x = _movingDraggedCell.center.x;
    newPoint.y -= _movingDistanceToOffset;
    [self _movingCellSetCenter:newPoint];
    
    [self _getDisplayingArea];
    [self _updateDisplayingArea];
    
    [self _movingCellToUpdateInPosition:newPoint.y];
}

- (void)_boundsScrollingIfNeeded {
    _movingScrollFate = 0;
    if (_movingDraggedCell.frame.origin.y < _contentOffset.beginPos + [self _contentInset].top) {
        if (_contentOffset.beginPos > -[self _contentInset].top) {
            _movingScrollFate = _movingDraggedCell.frame.origin.y - _contentOffset.beginPos - [self _contentInset].top;
            _movingScrollFate /= 10;
        }
    } else if (CGRectGetMaxY(_movingDraggedCell.frame) > _contentOffset.endPos - [self _contentInset].bottom) {
        if (_contentOffset.endPos < self.contentSize.height + [self _contentInset].bottom) {
            _movingScrollFate = CGRectGetMaxY(_movingDraggedCell.frame) - _contentOffset.endPos + [self _contentInset].bottom;
            _movingScrollFate /= 10;
        }
    }
    
    _movingDistanceToOffset = _contentOffset.beginPos - _movingDraggedCell.center.y;
    _movingScrollDisplayLink.paused = !_movingScrollFate;
}

- (void)_movingCellToUpdateInPosition:(CGFloat)position {
    if (position >= _contentDrawArea.beginPos && position <= _contentDrawArea.endPos) {
        if (position < _contentOffset.beginPos) {
            position = _contentOffset.beginPos;
        } else if (position > _contentOffset.endPos) {
            position = _contentOffset.endPos;
        }
        
        MPIndexPathStruct newIndexPath_ = [self _indexPathAtContentOffset:position - _contentDrawArea.beginPos];
        if (newIndexPath_.row == MPSectionTypeHeader) {
            newIndexPath_.row = 0;
        } else if (newIndexPath_.row == MPSectionTypeFooter) {
            if (newIndexPath_.section == _movingIndexPath.section) {
                return;
            }
            newIndexPath_.row = [self numberOfRowsInSection:newIndexPath_.section];
        } else {
            MPTableViewSection *section = _sectionsAreaList[newIndexPath_.section];
            CGFloat beginPos = [section rowPositionBeginAt:newIndexPath_.row];
            CGFloat endPos = [section rowPositionEndAt:newIndexPath_.row];
            CGFloat targetCenter = beginPos + (endPos - beginPos) / 2 + _contentDrawArea.beginPos;
            
            if (targetCenter < _movingDraggedCell.frame.origin.y || targetCenter > CGRectGetMaxY(_movingDraggedCell.frame)) { // must move across target's center.y
                return;
            }
        }
        
        if ([_movingIndexPath compareIndexPathAt:newIndexPath_] == NSOrderedSame) {
            return;
        }
        
        if ([self __isEstimatedMode] && (MPCompareIndexPath(newIndexPath_, _beginIndexPath) == NSOrderedAscending || MPCompareIndexPath(newIndexPath_, _endIndexPath) == NSOrderedDescending)) {
            return; // view at new indexPath may not has been estimated, or we should make a complete updating——that's too much trouble
        }
        
        MPIndexPath *newIndexPath = [MPIndexPath indexPathFromStruct:newIndexPath_];
        
        if (_respond_canMoveRowToIndexPath && ![_mpDataSource MPTableView:self canMoveRowToIndexPath:newIndexPath]) {
            return;
        }
        
        MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
        updateManager.moveFromSection = _movingIndexPath.section;
        updateManager.moveToSection = newIndexPath.section;
        
        [updateManager addMoveOutIndexPath:_movingIndexPath];
        
        [updateManager addMoveInIndexPath:newIndexPath withFrame:[self _cellFrameAtIndexPath:_movingIndexPath] withOriginIndexPath:_movingIndexPath];
        
        _movingIndexPath = newIndexPath;
        
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut completion:nil];
    }
}

- (void)_endMovingCellIfNeeded {
    if (!_movingScrollDisplayLink) {
        return;
    }
    
    MPIndexPath *sourceIndexPath = _sourceIndexPath;
    MPIndexPath *movingIndexPath = _movingIndexPath;
    
    if (_respond_moveRowAtIndexPathToIndexPath) {
        [_mpDataSource MPTableView:self moveRowAtIndexPath:sourceIndexPath toIndexPath:movingIndexPath];
    }
    
    [UIView animateWithDuration:MPTableViewDefaultAnimationDuration animations:^{
        CGRect frame = [self _cellFrameAtIndexPath:movingIndexPath];
        _movingDraggedCell.center = CGPointMake(frame.size.width / 2, (CGRectGetMaxY(frame) - frame.origin.y) / 2 + frame.origin.y);
    } completion:^(BOOL finished) {
        if (movingIndexPath == _movingIndexPath) {
            _sourceIndexPath = _movingIndexPath = nil;
            _movingDraggedCell = nil;
        }
        
        if (_respond_didEndMoveRowAtIndexPathToIndexPath) {
            [_mpDelegate MPTableView:self didEndMoveRowAtIndexPath:sourceIndexPath toIndexPath:movingIndexPath];
        }
        
        [self _clipCellsBetween:_beginIndexPath and:_endIndexPath];
    }];
    
    [_movingScrollDisplayLink invalidate];
    _movingScrollDisplayLink = nil;
}

@end