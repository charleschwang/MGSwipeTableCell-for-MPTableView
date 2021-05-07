//
//  MPTableViewSection.m
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableViewSection.h"
#import <vector>
#import <map>
#import <deque>
#import <algorithm>

using namespace std;

@implementation MPTableViewPosition

- (instancetype)init {
    if (self = [super init]) {
        _startPos = _endPos = 0;
    }
    return self;
}

+ (instancetype)positionStart:(CGFloat)start toEnd:(CGFloat)end {
    MPTableViewPosition *pos = [[[self class] alloc] init];
    pos.startPos = start;
    pos.endPos = end;
    return pos;
}

- (BOOL)isEqual:(id)object {
    if (!object) {
        return NO;
    } else {
        return _startPos == [object startPos] && _endPos == [object endPos];
    }
}

- (NSUInteger)hash {
    return (NSUInteger)fabs(_endPos);
}

- (id)copyWithZone:(NSZone *)zone {
    MPTableViewPosition *position = [[self class] allocWithZone:zone];
    position.startPos = _startPos;
    position.endPos = _endPos;
    return position;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@, startPosition:%.2f, endPosition:%.2f", [super description], _startPos, _endPos];
}

@end

#pragma mark -

class MPTableViewUpdateNode {
public:
    MPTableViewUpdateType updateType;
    MPTableViewRowAnimation animation;
    NSInteger index, lastIndex;
};

typedef vector<MPTableViewUpdateNode> MPTableViewUpdateNodes;

NS_INLINE bool
MPUpdateNodeSort(const MPTableViewUpdateNode &node1, const MPTableViewUpdateNode &node2) {
    return node1.index < node2.index;
}

static void
MPUpdateNodeMove(MPTableViewUpdateNodes &updateNodes, NSInteger lastIndex, NSInteger index) {
#if DEBUG
    assert(lastIndex < updateNodes.size() && index < updateNodes.size());
#endif
    
    NSInteger start;
    NSInteger middle;
    NSInteger end;
    if (index < lastIndex) {
        start = index;
        middle = lastIndex;
        end = lastIndex + 1;
    } else if (index > lastIndex) {
        start = lastIndex;
        middle = lastIndex + 1;
        end = index + 1;
    } else {
        return;
    }
    
    rotate(updateNodes.begin() + start, updateNodes.begin() + middle, updateNodes.begin() + end);
}

static void
MPUpdateNodesConverge(MPTableViewUpdateNodes &updateNodes) {
    sort(updateNodes.begin(), updateNodes.end(), MPUpdateNodeSort);
    
    NSInteger backTrackIndex = 0;
    NSInteger step = 0;
    NSInteger backTrackStep = 0;
    NSUInteger count = updateNodes.size();
    
    // make nodes not duplicate
    for (NSInteger i = 0; i < count; ++i) {
        MPTableViewUpdateNode *node = &updateNodes[i];
//        if (node->updateType == MPTableViewUpdateAdjust) {
//            continue;
//        }
        
        if (MPTV_UPDATE_TYPE_IS_UNSTABLE(node->updateType)) { // unstable
            node->index += step;
            if (node->updateType != MPTableViewUpdateReload) {
                --step;
            }
            while (backTrackIndex < i) {
                MPTableViewUpdateNode *backTrackNode = &updateNodes[backTrackIndex];
                if (MPTV_UPDATE_TYPE_IS_UNSTABLE(backTrackNode->updateType)) {
                    break;
                }
                if (node->index >= backTrackNode->index) { // unstable >= stable
                    ++node->index;
                    ++step;
                    ++backTrackIndex;
                } else {
                    MPUpdateNodeMove(updateNodes, i, backTrackIndex);
                    ++backTrackIndex;
                    break;
                }
            }
        } else { // stable
            while (backTrackIndex < i) {
                MPTableViewUpdateNode *backTrackNode = &updateNodes[backTrackIndex];
                if (MPTV_UPDATE_TYPE_IS_STABLE(backTrackNode->updateType)) {
                    break;
                }
                if (node->index <= (backTrackNode->index + backTrackStep)) { // stable <= unstable
                    MPUpdateNodeMove(updateNodes, i, backTrackIndex);
                    ++backTrackStep;
                    ++backTrackIndex;
                    break;
                } else if (backTrackStep != 0) {
                    NSInteger tracking = backTrackIndex;
                    while (true) {
                        backTrackNode->index += backTrackStep;
                        if (tracking + 1 >= i) {
                            break;
                        } else {
                            backTrackNode = &updateNodes[++tracking];
                        }
                    }
                    step += backTrackStep;
                    backTrackStep = 0;
                } else {
                    ++backTrackIndex;
                }
            }
        }
    }
    if (backTrackStep != 0) {
        do {
            MPTableViewUpdateNode *backTrackNode = &updateNodes[backTrackIndex++];
            backTrackNode->index += backTrackStep;
        } while (backTrackIndex < count);
    }
}

static bool
MPUpdateNodesBoundaryCheckReverse(const MPTableViewUpdateNodes &updateNodes, NSInteger count, bool isStable) {
    for (auto rfirst = updateNodes.rbegin(), rlast = updateNodes.rend(); rfirst != rlast; ++rfirst) {
        if (isStable) {
            if (MPTV_UPDATE_TYPE_IS_STABLE(rfirst->updateType)) {
                return rfirst->index < count;
            }
        } else {
            if (MPTV_UPDATE_TYPE_IS_UNSTABLE(rfirst->updateType)) {
                return rfirst->lastIndex < count;
            }
        }
    }
    
    return YES;
}

@implementation MPTableViewUpdateBase {
@public
    MPTableViewUpdateNodes _updateNodes;
}

- (instancetype)init {
    if (self = [super init]) {
        _existingStableIndexes = [[NSMutableIndexSet alloc] init];
        _existingUnstableIndexes = [[NSMutableIndexSet alloc] init];
        _differ = 0;
        _newCount = NSNotFound;
        _lastCount = NSNotFound;
    }
    return self;
}

- (BOOL)prepareToUpdateThenNeedToCheck:(BOOL)needToCheck {
    MPUpdateNodesConverge(_updateNodes);
    
    if (!needToCheck) {
        return YES;
    }
    
    if (self.lastCount + _differ != self.newCount) {
        return NO;
    } else {
        if (_updateNodes.size() == 0) {
            return YES;
        } else {
            return MPUpdateNodesBoundaryCheckReverse(_updateNodes, self.lastCount, false) && MPUpdateNodesBoundaryCheckReverse(_updateNodes, self.newCount, true);
        }
    }
}

- (void)dealloc {
    _existingUnstableIndexes = _existingStableIndexes = nil;
}

@end

#pragma mark -

@implementation MPTableViewUpdateManager {
    NSMutableIndexSet *_existingUpdatePartsIndexes;
    map<NSInteger, MPTableViewSection *> _movedSectionsMap;
}

- (instancetype)init {
    if (self = [super init]) {
        _existingUpdatePartsIndexes = [[NSMutableIndexSet alloc] init];
        _transactions = [[NSMutableArray alloc] init];
    }
    return self;
}

+ (MPTableViewUpdateManager *)managerForTableView:(MPTableView *)tableView andSectionsArray:(NSMutableArray *)sectionsArray {
    MPTableViewUpdateManager *manager = [[MPTableViewUpdateManager alloc] init];
    manager->_tableView = tableView;
    manager->_sectionsArray = sectionsArray;
    return manager;
}

- (void)reset {
    _updateNodes.clear();
    _movedSectionsMap.clear();
    
    [_existingStableIndexes removeAllIndexes];
    [_existingUnstableIndexes removeAllIndexes];
    [_existingUpdatePartsIndexes removeAllIndexes];
    
    [_transactions removeAllObjects];
    
    _differ = 0;
    self.lastCount = self.newCount = NSNotFound;
}

- (BOOL)hasUpdateNodes {
    if (_updateNodes.size() || _existingUpdatePartsIndexes.count) {
        return YES;
    } else {
        return NO;
    }
}

- (void)dealloc {
    [_existingUpdatePartsIndexes removeAllIndexes];
    _existingUpdatePartsIndexes = nil;
}

#pragma mark -

- (BOOL)addDeleteSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:section] || [_existingUpdatePartsIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:section];
        --_differ;
    }
    
    MPTableViewUpdateNode node;
    node.index = section;
    node.lastIndex = section;
    node.updateType = MPTableViewUpdateDelete;
    node.animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addInsertSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingStableIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingStableIndexes addIndex:section];
        ++_differ;
    }
    
    MPTableViewUpdateNode node;
    node.index = section;
    node.lastIndex = section;
    node.updateType = MPTableViewUpdateInsert;
    node.animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addReloadSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:section] || [_existingUpdatePartsIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:section];
    }
    
    MPTableViewUpdateNode node;
    node.index = section;
    node.lastIndex = section;
    node.updateType = MPTableViewUpdateReload;
    node.animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addMoveOutSection:(NSInteger)section {
    if ([_existingUnstableIndexes containsIndex:section] || [_existingUpdatePartsIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:section];
        --_differ;
    }
    
    MPTableViewUpdateNode node;
    node.index = section;
    node.lastIndex = section;
    node.updateType = MPTableViewUpdateMoveOut;
    node.animation = MPTableViewRowAnimationNone;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addMoveInSection:(NSInteger)section withLastSection:(NSInteger)lastSection {
    if ([_existingStableIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingStableIndexes addIndex:section];
        ++_differ;
    }
    
    MPTableViewUpdateNode node;
    node.index = section;
    node.lastIndex = section;
    node.updateType = MPTableViewUpdateMoveIn;
    node.animation = MPTableViewRowAnimationNone;
    
    _updateNodes.push_back(node);
    _movedSectionsMap.insert(pair<NSInteger, MPTableViewSection *>(section, _sectionsArray[lastSection]));
    return YES;
}

#pragma mark -

- (MPTableViewUpdatePart *)getPartFromSection:(NSInteger)section {
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    MPTableViewUpdatePart *part = sectionPosition.updatePart;
    if (!part) {
        part = [[MPTableViewUpdatePart alloc] init];
        sectionPosition.updatePart = part;
        [_existingUpdatePartsIndexes addIndex:section];
    }
    return part;
}

- (BOOL)addDeleteIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self getPartFromSection:indexPath.section];
    return [part addDeleteRow:indexPath.row withAnimation:animation];
}

- (BOOL)addInsertIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self getPartFromSection:indexPath.section];
    return [part addInsertRow:indexPath.row withAnimation:animation];
}

- (BOOL)addReloadIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self getPartFromSection:indexPath.section];
    return [part addReloadRow:indexPath.row withAnimation:animation];
}

- (BOOL)addMoveOutIndexPath:(NSIndexPath *)indexPath {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self getPartFromSection:indexPath.section];
    return [part addMoveOutRow:indexPath.row];
}

- (BOOL)addMoveInIndexPath:(NSIndexPath *)indexPath withLastIndexPath:(NSIndexPath *)lastIndexPath withLastFrame:(CGRect)lastFrame {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self getPartFromSection:indexPath.section];
    return [part addMoveInRow:indexPath.row withLastIndexPath:lastIndexPath withLastFrame:lastFrame];
}

#pragma mark -

- (CGFloat)update {
    CGFloat offset = 0;
    NSInteger sectionsCount = self.lastCount; // verified
    
    NSInteger index = 0, step = 0;
    NSUInteger nodesCount = _updateNodes.size();
    BOOL hasDraggingCell = [_tableView _hasDraggingCell];
    
    for (NSInteger i = 0; i < nodesCount; ++i) {
        const MPTableViewUpdateNode &node = _updateNodes[i];
        
        for (NSInteger j = index; j < node.index; ++j) {
            MPTableViewSection *section = _sectionsArray[j];
            BOOL needToDisplay = [_tableView _updateNeedToDisplaySection:section withUpdateType:MPTableViewUpdateAdjust withOffset:offset];
            if (MPTV_UPDATE_TYPE_IS_UNSTABLE(node.updateType)) {
                needToDisplay = needToDisplay && section.section < node.lastIndex;
            }
            
            offset = [self _updateSectionPosition:section toNewSection:j needToDisplay:needToDisplay hasDraggingCell:hasDraggingCell withOffset:offset];
        }
        
        if (MPTV_UPDATE_TYPE_IS_STABLE(node.updateType)) {
            ++step;
            
            if (node.updateType == MPTableViewUpdateInsert) {
                MPTableViewSection *insertSection = [_tableView _updateBuildSection:node.index];
                [_sectionsArray insertObject:insertSection atIndex:node.index];
                
                [insertSection rebuildForTableView:_tableView withLastSection:node.index withDistance:0 isMovement:NO];
                
                [self _executeInsertionsForSection:insertSection andNode:node];
                
                offset += insertSection.endPos - insertSection.startPos;
            } else {
                MPTableViewSection *moveInSection = _movedSectionsMap.at(node.index);
                MPTableViewSection *backup = [moveInSection copy];
                
                moveInSection.section = node.index;
                if (moveInSection.moveOutHeight == MPTableViewInvalidFloat) {
                    moveInSection.moveOutHeight = moveInSection.endPos - moveInSection.startPos;
                } else {
                    moveInSection.moveOutHeight = MPTableViewInvalidFloat;
                }
                
                CGFloat startPos;
                if (node.index == 0) {
                    startPos = 0;
                } else { // because _sectionsArray[node.index] has not been calculated, so its position is not accurate
                    MPTableViewSection *frontSection = _sectionsArray[node.index - 1];
                    startPos = frontSection.endPos;
                }
                CGFloat distance = startPos - moveInSection.startPos;
                [moveInSection makeOffset:distance];
                
                [_sectionsArray insertObject:moveInSection atIndex:node.index];
                
                [moveInSection rebuildForTableView:_tableView withLastSection:backup.section withDistance:distance isMovement:YES];
                
                [self _executeMovementsForSection:moveInSection fromLastSection:backup andNode:node withDistance:distance];
                
                offset += moveInSection.endPos - moveInSection.startPos;
            }
            
            index = node.index + 1;
        } else if (node.updateType == MPTableViewUpdateReload) {
            MPTableViewSection *deleteSection = _sectionsArray[node.index];
            MPTableViewSection *insertSection = [_tableView _updateBuildSection:node.index];
            NSAssert(node.lastIndex == deleteSection.section, @"An unexpected bug, please contact the author"); // beyond the bug
            
            [_sectionsArray replaceObjectAtIndex:node.index withObject:insertSection];
            [insertSection rebuildForTableView:_tableView withLastSection:node.index withDistance:0 isMovement:NO];
            
            // node.index - step == node.lastIndex
            CGFloat height = insertSection.endPos - insertSection.startPos;
            offset += height - (deleteSection.endPos - deleteSection.startPos);
            
            if ([_tableView _updateNeedToDisplaySection:deleteSection withUpdateType:MPTableViewUpdateDelete withOffset:0]) {
                for (NSInteger k = 0; k < deleteSection.numberOfRows; ++k) {
                    [_tableView _updateDeleteCellInSection:node.lastIndex atRow:k withAnimation:node.animation inSectionPosition:deleteSection];
                }
                
                [_tableView _updateDeleteSectionViewInSection:node.lastIndex withType:MPSectionHeader withAnimation:node.animation withDeleteSection:deleteSection];
                [_tableView _updateDeleteSectionViewInSection:node.lastIndex withType:MPSectionFooter withAnimation:node.animation withDeleteSection:deleteSection];
            }
            
            [self _executeInsertionsForSection:insertSection andNode:node];
            
            index = node.index + 1;
        } else { // node.updateType == MPTableViewUpdateDelete || node.updateType == MPTableViewUpdateMoveOut
            --step;
            
            MPTableViewSection *deleteSection = _sectionsArray[node.index];
            CGFloat height;
            if (node.updateType == MPTableViewUpdateDelete) {
                height = deleteSection.endPos - deleteSection.startPos;
            } else {
                if (deleteSection.moveOutHeight == MPTableViewInvalidFloat) {
                    deleteSection.moveOutHeight = height = deleteSection.endPos - deleteSection.startPos;
                } else {
                    height = deleteSection.moveOutHeight;
                    deleteSection.moveOutHeight = MPTableViewInvalidFloat;
                }
            }
            offset -= height;
            [_sectionsArray removeObjectAtIndex:node.index];
            
            // node.index - step - 1 == node.lastIndex
            if (node.updateType == MPTableViewUpdateDelete && [_tableView _updateNeedToDisplaySection:deleteSection withUpdateType:MPTableViewUpdateDelete withOffset:0]) {
                for (NSInteger k = 0; k < deleteSection.numberOfRows; ++k) {
                    [_tableView _updateDeleteCellInSection:node.lastIndex atRow:k withAnimation:node.animation inSectionPosition:deleteSection];
                }
                
                [_tableView _updateDeleteSectionViewInSection:node.lastIndex withType:MPSectionHeader withAnimation:node.animation withDeleteSection:deleteSection];
                [_tableView _updateDeleteSectionViewInSection:node.lastIndex withType:MPSectionFooter withAnimation:node.animation withDeleteSection:deleteSection];
            }
            
            index = node.index;
        }
    }
    
    sectionsCount += step;
    NSInteger j = index;
    
    if (hasDraggingCell) {
        if (_dragToSection > _dragFromSection) {
            j = _dragFromSection;
            sectionsCount = _dragToSection + 1;
        } else {
            j = _dragToSection;
            sectionsCount = _dragFromSection + 1;
        }
    }
    
    for (; j < sectionsCount; ++j) {
        MPTableViewSection *section = _sectionsArray[j];
        NSAssert(section.section == j - step, @"An unexpected bug, please contact the author");
        
        BOOL needToDisplay = [_tableView _updateNeedToDisplaySection:section withUpdateType:MPTableViewUpdateAdjust withOffset:offset];
        
        offset = [self _updateSectionPosition:section toNewSection:j needToDisplay:needToDisplay hasDraggingCell:hasDraggingCell withOffset:offset];
    }
    
    return offset;
}

- (CGFloat)_updateSectionPosition:(MPTableViewSection *)sectionPosition toNewSection:(NSInteger)newSection needToDisplay:(BOOL)needToDisplay hasDraggingCell:(BOOL)hasDraggingCell withOffset:(CGFloat)offset {
    NSInteger numberOfRows = hasDraggingCell ? sectionPosition.numberOfRows : [_tableView.dataSource MPTableView:_tableView numberOfRowsInSection:newSection];
    if (numberOfRows < 0) {
        NSAssert(NO, @"the number of rows in section can not be negative");
        numberOfRows = 0;
    }
    
    if (sectionPosition.updatePart) {
        BOOL needToCheck = !hasDraggingCell;
        if (needToCheck) {
            sectionPosition.updatePart.lastCount = sectionPosition.numberOfRows;
            sectionPosition.updatePart.newCount = numberOfRows;
        }
        if (![sectionPosition.updatePart prepareToUpdateThenNeedToCheck:needToCheck]) {
            MPTV_EXCEPTION(@"check the number of rows after insert or delete")
        }
        
        offset = [sectionPosition updateWithPartForTableView:_tableView toNewSection:newSection withOffset:offset needToDisplay:needToDisplay];
    } else {
        if (numberOfRows != sectionPosition.numberOfRows) {
            MPTV_EXCEPTION(@"check the number of rows from data source")
        }
        
        offset = [sectionPosition updateForTableView:_tableView toNewSection:newSection withOffset:offset needToDisplay:needToDisplay];
    }
    
    return offset;
}

- (void)_executeInsertionsForSection:(MPTableViewSection *)insertSection andNode:(MPTableViewUpdateNode)node {
    CGFloat updateLastInsertionOriginY = [_tableView _updateLastInsertionOriginY];
    void (^updateAction)(void) = ^{
        if (!_tableView) {
            return;
        }
        
        if (![_tableView _updateNeedToDisplaySection:insertSection withUpdateType:MPTableViewUpdateInsert withOffset:0]) { // content offset may have been changed
            return;
        }
        
        for (NSInteger k = 0; k < insertSection.numberOfRows; ++k) {
            [_tableView _updateInsertCellToSection:node.index atRow:k withAnimation:node.animation inSectionPosition:insertSection withLastInsertionOriginY:updateLastInsertionOriginY];
        }
        
        [_tableView _updateInsertSectionViewToSection:node.index withType:MPSectionHeader withAnimation:node.animation withInsertSection:insertSection withLastInsertionOriginY:updateLastInsertionOriginY];
        [_tableView _updateInsertSectionViewToSection:node.index withType:MPSectionFooter withAnimation:node.animation withInsertSection:insertSection withLastInsertionOriginY:updateLastInsertionOriginY];
    };
    
    [[_tableView _updateExecutionActions] addObject:updateAction];
}

- (void)_executeMovementsForSection:(MPTableViewSection *)insertSection fromLastSection:(MPTableViewSection *)lastSection andNode:(MPTableViewUpdateNode)node withDistance:(CGFloat)distance {
    BOOL needToDisplay = [_tableView _updateNeedToDisplaySection:lastSection withUpdateType:MPTableViewUpdateMoveOut withOffset:0];
    void (^updateAction)(void) = ^{
        if (!_tableView) {
            return;
        }
        
        if (!needToDisplay && ![_tableView _updateNeedToDisplaySection:insertSection withUpdateType:MPTableViewUpdateMoveIn withOffset:distance]) {
            return;
        }
        
        for (NSInteger k = 0; k < insertSection.numberOfRows; ++k) {
            [_tableView _updateMoveCellToSection:node.index atRow:k fromLastSection:lastSection.section andLastRow:k withLastHeight:[lastSection heightAtRow:k] withDistance:distance];
        }
        
        [_tableView _updateMoveSectionViewToSection:node.index fromLastSection:lastSection.section withType:MPSectionHeader withLastHeight:lastSection.headerHeight withDistance:distance];
        [_tableView _updateMoveSectionViewToSection:node.index fromLastSection:lastSection.section withType:MPSectionFooter withLastHeight:lastSection.footerHeight withDistance:distance];
    };
    
    [[_tableView _updateExecutionActions] addObject:updateAction];
}

@end

#pragma mark -

class MPTableViewUpdateRowInfo {
public:
    NSIndexPath *indexPath;
    CGFloat originY, height;
    
    ~MPTableViewUpdateRowInfo() {
        indexPath = nil;
    }
};

@implementation MPTableViewUpdatePart {
    @package
    map<NSInteger, MPTableViewUpdateRowInfo> _moveOutRowInfosMap;
}

- (BOOL)addDeleteRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:row];
        --_differ;
    }
    
    MPTableViewUpdateNode node;
    node.index = row;
    node.lastIndex = row;
    node.updateType = MPTableViewUpdateDelete;
    node.animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addInsertRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingStableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingStableIndexes addIndex:row];
        ++_differ;
    }
    
    MPTableViewUpdateNode node;
    node.index = row;
    node.lastIndex = row;
    node.updateType = MPTableViewUpdateInsert;
    node.animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addReloadRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:row];
    }
    
    MPTableViewUpdateNode node;
    node.index = row;
    node.lastIndex = row;
    node.updateType = MPTableViewUpdateReload;
    node.animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addMoveOutRow:(NSInteger)row {
    if ([_existingUnstableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:row];
        --_differ;
    }
    
    MPTableViewUpdateNode node;
    node.index = row;
    node.lastIndex = row;
    node.updateType = MPTableViewUpdateMoveOut;
    node.animation = MPTableViewRowAnimationNone;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addMoveInRow:(NSInteger)row withLastIndexPath:(NSIndexPath *)lastIndexPath withLastFrame:(CGRect)lastFrame {
    if ([_existingStableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingStableIndexes addIndex:row];
        ++_differ;
    }
    
    MPTableViewUpdateNode node;
    node.index = row;
    node.lastIndex = row;
    node.updateType = MPTableViewUpdateMoveIn;
    node.animation = MPTableViewRowAnimationNone;
    
    _updateNodes.push_back(node);
    
    MPTableViewUpdateRowInfo rowInfo;
    rowInfo.indexPath = lastIndexPath;
    rowInfo.originY = lastFrame.origin.y;
    rowInfo.height = lastFrame.size.height;
    
    _moveOutRowInfosMap.insert(pair<NSInteger, MPTableViewUpdateRowInfo>(row, rowInfo));
    return YES;
}

@end

#pragma mark -

@implementation MPTableViewSection {
    deque<CGFloat> _rowPositions;
}

+ (instancetype)section {
    return [[[self class] alloc] init];
}

- (instancetype)init {
    if (self = [super init]) {
        [self reset];
    }
    return self;
}

- (void)reset {
    if (_rowPositions.size()) {
        _rowPositions.clear();
    }
    
    _numberOfRows = 0;
    self.startPos = self.endPos = 0;
    _headerHeight = _footerHeight = 0;
    _section = NSNotFound;
    _moveOutHeight = MPTableViewInvalidFloat;
    
    _updatePart = nil;
}

- (void)addRowPosition:(CGFloat)position {
    _rowPositions.push_back(position);
}

- (CGFloat)startPositionAtRow:(NSInteger)row {
    return _rowPositions[row];
}

- (CGFloat)endPositionAtRow:(NSInteger)row {
    return _rowPositions[row + 1];
}

- (CGFloat)heightAtRow:(NSInteger)row {
    return _rowPositions[row + 1] - _rowPositions[row];
}

- (NSInteger)rowAtContentOffsetY:(CGFloat)contentOffsetY {
    if (_headerHeight > 0 && (contentOffsetY <= self.startPos + _headerHeight)) {
        return MPSectionHeader;
    }
    if (_footerHeight > 0 && (contentOffsetY >= self.endPos - _footerHeight)) {
        return MPSectionFooter;
    }
    
    NSInteger start = 0;
    NSInteger end = _numberOfRows - 1;
    NSInteger middle = 0;
    while (start <= end) {
        middle = (start + end) / 2;
        CGFloat startPos = [self startPositionAtRow:middle];
        CGFloat endPos = [self endPositionAtRow:middle];
        if (startPos > contentOffsetY) {
            end = middle - 1;
        } else if (endPos < contentOffsetY) {
            start = middle + 1;
        } else {
            return middle;
        }
    }
    
    return middle; // floating-point precision
}

- (id)copyWithZone:(NSZone *)zone {
    MPTableViewSection *section = [super copyWithZone:zone];
    section.section = _section;
    section.headerHeight = _headerHeight;
    section.footerHeight = _footerHeight;
    section->_rowPositions = _rowPositions;
    section.numberOfRows = _numberOfRows;
    section.moveOutHeight = _moveOutHeight;
    
    return section;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@, section:%zd, numberOfRows:%zd, headerHeight:%.2f, footerHeight:%.2f", [super description], _section, _numberOfRows, _headerHeight, _footerHeight];
}

#pragma mark -

- (void)_removeRowPositionAtIndex:(NSInteger)index {
    auto it = _rowPositions.begin() + index + 1;
    _rowPositions.erase(it);
}

- (void)_insertRow:(NSInteger)row withHeight:(CGFloat)height {
    auto it = _rowPositions.begin() + row + 1;
    CGFloat endPos = height + _rowPositions[row];
    _rowPositions.insert(it, endPos);
}

- (void)_reloadRow:(NSInteger)row withHeight:(CGFloat)height {
    _rowPositions[row + 1] = _rowPositions[row] + height;
}

- (void)makeOffset:(CGFloat)offset {
    if (offset == 0) {
        return;
    }
    
    self.startPos += offset;
    self.endPos += offset;
    for (NSInteger i = 0; i <= _numberOfRows; ++i) {
        _rowPositions[i] += offset;
    }
}

- (CGFloat)_updateRowForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withOffset:(CGFloat)offset hasDraggingCell:(BOOL)hasDraggingCell needToLoadHeight:(BOOL *)needToLoadHeight {
    CGFloat lastOffset = offset;
    CGFloat lastHeight = [self heightAtRow:row];
    
    if (*needToLoadHeight == YES) {
        CGFloat differ = [tableView _updateGetAdjustCellDifferInSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withOffset:offset needToLoadHeight:needToLoadHeight];
        if (differ != 0) {
            offset += differ;
            _rowPositions[row + 1] += differ;
        }
    }
    
    [self _adjustCellsForTableView:tableView toNewSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withLastHeight:lastHeight withOffset:lastOffset hasDraggingCell:hasDraggingCell];
    
    return offset;
}

- (void)_adjustCellsForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withLastHeight:(CGFloat)lastHeight withOffset:(CGFloat)offset hasDraggingCell:(BOOL)hasDraggingCell {
    if (hasDraggingCell) {
        [tableView _updateAdjustCellToSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withLastHeight:lastHeight withOffset:offset];
    } else {
        void (^updateAction)(void) = ^{
            if (!tableView) {
                return;
            }
            
            [tableView _updateAdjustCellToSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withLastHeight:lastHeight withOffset:offset];
        };
        [[tableView _updateExecutionActions] addObject:updateAction];
    }
}

- (CGFloat)_updateHeaderForTableView:(MPTableView *)tableView fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isMovement:(BOOL)isMovement {
    CGFloat headerHeight = [tableView _updateGetHeaderHeightInSection:self fromLastSection:lastSection withOffset:offset isMovement:isMovement];
    if (headerHeight >= 0) {
        offset += headerHeight - _headerHeight;
        _headerHeight = headerHeight;
    }
    
    return offset;
}

- (CGFloat)_updateFooterForTableView:(MPTableView *)tableView fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isMovement:(BOOL)isMovement {
    CGFloat footerHeight = [tableView _updateGetFooterHeightInSection:self fromLastSection:lastSection withOffset:offset isMovement:isMovement];
    if (footerHeight >= 0) {
        CGFloat differ = footerHeight - _footerHeight;
        offset += differ;
        self.endPos += differ;
        _footerHeight = footerHeight;
    }
    
    return offset;
}

- (void)_adjustSectionViewsForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection fromLastSection:(NSInteger)lastSection withHeaderOffset:(CGFloat)headerOffset andFooterOffset:(CGFloat)footerOffset withLastHeaderHeight:(CGFloat)lastHeaderHeight andLastFooterHeight:(CGFloat)lastFooterHeight needToDisplay:(BOOL)needToDisplay {
    BOOL needToAdjustHeader = needToDisplay || [tableView _updateNeedToAdjustSectionViewInLastSection:lastSection withType:MPSectionHeader];
    BOOL needToAdjustFooter = needToDisplay || [tableView _updateNeedToAdjustSectionViewInLastSection:lastSection withType:MPSectionFooter];
    
    if (needToAdjustHeader) {
        void (^updateAction)(void) = ^{
            if (!tableView) {
                return;
            }
            
            [tableView _updateAdjustSectionViewFromSection:lastSection toSection:newSection withType:MPSectionHeader withLastHeight:lastHeaderHeight withOffset:headerOffset];
        };
        [[tableView _updateExecutionActions] addObject:updateAction];
    }
    
    if (needToAdjustFooter) {
        void (^updateAction)(void) = ^{
            if (!tableView) {
                return;
            }
            
            [tableView _updateAdjustSectionViewFromSection:lastSection toSection:newSection withType:MPSectionFooter withLastHeight:lastFooterHeight withOffset:footerOffset];
        };
        [[tableView _updateExecutionActions] addObject:updateAction];
    }
}

- (CGFloat)updateWithPartForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay {
    [tableView _setUpdateLastInsertionOriginY:self.startPos + _headerHeight];
    
    self.startPos += offset;
    NSInteger lastSection = _section;
    _section = newSection;
    CGFloat headerOffset = offset;
    CGFloat lastHeaderHeight = _headerHeight, lastFooterHeight = _footerHeight;
    BOOL hasDraggingCell = [tableView _hasDraggingCell];
    
    if (needToDisplay && !hasDraggingCell) {
        CGFloat lastOffset = offset;
        self.endPos += lastOffset; // as a reference
        offset = [self _updateHeaderForTableView:tableView fromLastSection:lastSection withOffset:offset isMovement:NO];
        self.endPos -= lastOffset; // reset the reference
    }
    
    [tableView _setUpdateLastDeletionOriginY:self.startPos + _headerHeight];
    
    _rowPositions[0] += offset;
    
    NSInteger index = 1, step = 0;
    NSUInteger nodesCount = _updatePart->_updateNodes.size();
    BOOL isBeginSection = (lastSection == [tableView _beginSection]);
    BOOL isEndSection = (lastSection == [tableView _endSection]);
    NSInteger beginSectionRow = [tableView _beginRow];
    NSInteger endSectionRow = [tableView _endRow];
    BOOL hasCells = [tableView _updateNeedToAdjustCellsFromLastSection:lastSection];
    
    for (NSInteger i = 0; i < nodesCount; ++i) {
        const MPTableViewUpdateNode &node = _updatePart->_updateNodes[i];
        NSInteger idx;
        BOOL isInsertion;
        
        if (MPTV_UPDATE_TYPE_IS_STABLE(node.updateType)) {
            idx = node.index;
            isInsertion = YES;
        } else {
            idx = node.index + 1;
            isInsertion = NO;
        }
        
        BOOL needCallback = !hasDraggingCell && (offset != 0 || needToDisplay || hasCells);
        needCallback = needCallback || (hasDraggingCell && offset != 0);
        if (needCallback) {
            BOOL needToLoadHeight = !hasDraggingCell;
            for (NSInteger j = index; j <= idx; ++j) {
                [tableView _setUpdateLastInsertionOriginY:_rowPositions[j]];
                
                if (offset != 0) {
                    _rowPositions[j] += offset;
                }
                
                NSInteger row = j - 1;
                NSInteger lastRow = j - step - 1;
                
                BOOL needToAdjust = NO;
                if (isInsertion || lastRow < node.lastIndex) {
                    if (hasCells) {
                        needToAdjust = [tableView _updateNeedToAdjustCellToSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow] || needToDisplay; // can't put this "needToDisplay" on left
                    } else {
                        needToAdjust = needToDisplay;
                    }
                }
                
                if (hasDraggingCell && ((isBeginSection && MPTV_ROW_LESS(lastRow, beginSectionRow)) || (isEndSection && MPTV_ROW_MORE(lastRow, endSectionRow)))) {
                    continue;
                }
                
                if (needToAdjust) {
                    offset = [self _updateRowForTableView:tableView toNewSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withOffset:offset hasDraggingCell:hasDraggingCell needToLoadHeight:&needToLoadHeight];
                    
                    [tableView _setUpdateLastDeletionOriginY:_rowPositions[j]];
                } else if (offset == 0 && !hasCells) {
                    break;
                }
            }
        }
        
        if (isInsertion) {
            ++step;
            
            CGFloat height;
            if (node.updateType == MPTableViewUpdateInsert) {
                height = [tableView _updateGetInsertCellHeightInSection:newSection atRow:node.index];
                [self _insertRow:node.index withHeight:height];
                offset += height;
                
                if (needToDisplay) {
                    CGFloat updateLastInsertionOriginY = [tableView _updateLastInsertionOriginY];
                    NSInteger row = node.index; // A C++ reference will be released in an Objective-C block in release mode
                    MPTableViewRowAnimation animation = node.animation;
                    void (^updateAction)(void) = ^{
                        if (!tableView) { // necessary
                            return;
                        }
                        [tableView _updateInsertCellToSection:newSection atRow:row withAnimation:animation inSectionPosition:nil withLastInsertionOriginY:updateLastInsertionOriginY];
                    };
                    [[tableView _updateExecutionActions] addObject:updateAction];
                }
            } else {
                const MPTableViewUpdateRowInfo &rowInfo = _updatePart->_moveOutRowInfosMap.at(node.index);
                height = rowInfo.height;
                [self _insertRow:node.index withHeight:height];
                offset += height;
                
                CGFloat distance = [self startPositionAtRow:node.index] - rowInfo.originY;
                
                if (hasDraggingCell) {
                    [tableView _updateMoveCellToSection:newSection atRow:node.index fromLastSection:rowInfo.indexPath.section andLastRow:rowInfo.indexPath.row withLastHeight:height withDistance:distance];
                } else {
                    CGFloat differ = [tableView _updateGetMoveInCellDifferInSection:newSection atRow:node.index fromLastIndexPath:rowInfo.indexPath withLastHeight:height withDistance:distance];
                    if (differ != 0) {
                        offset += differ;
                        _rowPositions[node.index + 1] += differ;
                    }
                    
                    NSInteger row = node.index;
                    NSIndexPath *lastIndexPath = rowInfo.indexPath;
                    void (^updateAction)(void) = ^{
                        if (!tableView) {
                            return;
                        }
                        [tableView _updateMoveCellToSection:newSection atRow:row fromLastSection:lastIndexPath.section andLastRow:lastIndexPath.row withLastHeight:height withDistance:distance];
                    };
                    [[tableView _updateExecutionActions] addObject:updateAction];
                }
            }
            
            index = node.index + 2;
        } else if (node.updateType == MPTableViewUpdateReload) {
            CGFloat height = [tableView _updateGetInsertCellHeightInSection:newSection atRow:node.index];
            offset += height - [self heightAtRow:node.index];
            [self _reloadRow:node.index withHeight:height];
            
            // node.index - step == node.lastIndex
            [tableView _updateDeleteCellInSection:lastSection atRow:node.lastIndex withAnimation:node.animation inSectionPosition:nil];
            if (needToDisplay) {
                CGFloat updateLastInsertionOriginY = [tableView _updateLastInsertionOriginY];
                NSInteger row = node.index;
                MPTableViewRowAnimation animation = node.animation;
                void (^updateAction)(void) = ^{
                    if (!tableView) { // necessary
                        return;
                    }
                    [tableView _updateInsertCellToSection:newSection atRow:row withAnimation:animation inSectionPosition:nil withLastInsertionOriginY:updateLastInsertionOriginY];
                };
                [[tableView _updateExecutionActions] addObject:updateAction];
            }
            
            index = node.index + 2;
        } else { // node.updateType == MPTableViewUpdateDelete || node.updateType == MPTableViewUpdateMoveOut
            --step;
            
            CGFloat height = [self heightAtRow:node.index];
            offset -= height;
            [self _removeRowPositionAtIndex:node.index];
            
            // node.index - step - 1 == node.lastIndex
            if (node.updateType == MPTableViewUpdateDelete) {
                [tableView _updateDeleteCellInSection:lastSection atRow:node.lastIndex withAnimation:node.animation inSectionPosition:nil];
            }
            
            index = node.index + 1;
        }
    }
    
    _numberOfRows += step;
    
    BOOL needCallback = !hasDraggingCell && (offset != 0 || needToDisplay || hasCells);
    needCallback = needCallback || (hasDraggingCell && step != 0);
    if (needCallback) {
        BOOL needToLoadHeight = !hasDraggingCell;
        for (NSInteger j = index; j <= _numberOfRows; ++j) {
            if (offset != 0) {
                _rowPositions[j] += offset;
            }
            
            NSInteger row = j - 1;
            NSInteger lastRow = j - step - 1;
            
            BOOL needToAdjust;
            if (hasCells) {
                needToAdjust = [tableView _updateNeedToAdjustCellToSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow] || needToDisplay;
            } else {
                needToAdjust = needToDisplay;
            }
            
            if (hasDraggingCell && ((isBeginSection && MPTV_ROW_LESS(lastRow, beginSectionRow)) || (isEndSection && MPTV_ROW_MORE(lastRow, endSectionRow)))) {
                continue;
            }
            
            if (needToAdjust) {
                offset = [self _updateRowForTableView:tableView toNewSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withOffset:offset hasDraggingCell:hasDraggingCell needToLoadHeight:&needToLoadHeight];
            } else if (offset == 0 && !hasCells) {
                break;
            }
        }
    }
    
    [tableView _setUpdateLastInsertionOriginY:self.endPos];
    
    self.endPos += offset;
    CGFloat footerOffset = offset;
    
    if (needToDisplay && !hasDraggingCell) {
        offset = [self _updateFooterForTableView:tableView fromLastSection:lastSection withOffset:offset isMovement:NO];
    }
    
    [tableView _setUpdateLastDeletionOriginY:self.endPos];
    
    [self _adjustSectionViewsForTableView:tableView toNewSection:newSection fromLastSection:lastSection withHeaderOffset:headerOffset andFooterOffset:footerOffset withLastHeaderHeight:lastHeaderHeight andLastFooterHeight:lastFooterHeight needToDisplay:needToDisplay];
    
    _updatePart = nil;
    
    return offset;
}

- (CGFloat)updateForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay {
    BOOL necessaryToDisplay = (offset != 0) && [tableView _updateNecessaryToAdjustSection:self withOffset:offset];
    CGFloat lastOffset = offset;
    
    self.startPos += offset;
    NSInteger lastSection = _section;
    _section = newSection;
    CGFloat headerOffset = offset;
    CGFloat lastHeaderHeight = _headerHeight, lastFooterHeight = _footerHeight;
    BOOL hasDraggingCell = [tableView _hasDraggingCell];
    
    if (needToDisplay && !hasDraggingCell) {
        self.endPos += lastOffset; // as a reference
        offset = [self _updateHeaderForTableView:tableView fromLastSection:lastSection withOffset:offset isMovement:NO];
        self.endPos -= lastOffset; // reset the reference
    }
    
    _rowPositions[0] += offset;
    
    BOOL hasCells = [tableView _updateNeedToAdjustCellsFromLastSection:lastSection];
    if (offset != 0 || needToDisplay || hasCells) {
        BOOL needToLoadHeight = !hasDraggingCell;
        for (NSInteger i = 0; i < _numberOfRows; ++i) {
            if (offset != 0) {
                _rowPositions[i + 1] += offset;
            }
            
            BOOL needToAdjust;
            if (hasCells) {
                needToAdjust = [tableView _updateNeedToAdjustCellToSection:newSection atRow:i fromLastSection:lastSection andLastRow:i] || needToDisplay;
            } else {
                needToAdjust = needToDisplay;
            }
            
            if (needToAdjust) {
                offset = [self _updateRowForTableView:tableView toNewSection:newSection atRow:i fromLastSection:lastSection andLastRow:i withOffset:offset hasDraggingCell:hasDraggingCell needToLoadHeight:&needToLoadHeight];
            } else {
                if (offset == 0 && !hasCells) {
                    break;
                } else if (necessaryToDisplay) {
                    [self _adjustCellsForTableView:tableView toNewSection:newSection atRow:i fromLastSection:lastSection andLastRow:i withLastHeight:[self heightAtRow:i] withOffset:offset hasDraggingCell:hasDraggingCell];
                }
            }
        }
    }
    
    [tableView _setUpdateLastInsertionOriginY:self.endPos];
    
    self.endPos += offset;
    CGFloat footerOffset = offset;
    
    if (needToDisplay && !hasDraggingCell) {
        offset = [self _updateFooterForTableView:tableView fromLastSection:lastSection withOffset:offset isMovement:NO];
    }
    
    [tableView _setUpdateLastDeletionOriginY:self.endPos];
    
    [self _adjustSectionViewsForTableView:tableView toNewSection:newSection fromLastSection:lastSection withHeaderOffset:headerOffset andFooterOffset:footerOffset withLastHeaderHeight:lastHeaderHeight andLastFooterHeight:lastFooterHeight needToDisplay:needToDisplay || necessaryToDisplay];
    
    return offset;
}

- (void)rebuildForTableView:(MPTableView *)tableView withLastSection:(NSInteger)lastSection withDistance:(CGFloat)distance isMovement:(BOOL)isMovement {    
    if ([tableView _isEstimatedMode]) {
        if (!tableView.forcesReloadDuringUpdate) {
            if (isMovement) {
                NSInteger section = _section;
                _section = lastSection;
                BOOL needToDisplay = [tableView _updateNeedToDisplaySection:self withUpdateType:MPTableViewUpdateMoveIn withOffset:distance] || [tableView _hasDisplayedSection:self];
                _section = section;
                
                if (!needToDisplay) {
                    return;
                }
            } else if (![tableView _updateNeedToDisplaySection:self withUpdateType:MPTableViewUpdateInsert withOffset:0]) {
                return;
            }
        }
    } else {
        if (!isMovement) { // non-estimated insertion
            return;
        }
    }
    
    // for estimated movement and insertion, non-estimated movement
    CGFloat offset = 0;
    
    if (isMovement || [tableView _hasEstimatedHeightForHeader]) {
        offset = [self _updateHeaderForTableView:tableView fromLastSection:lastSection withOffset:distance isMovement:isMovement];
        offset -= distance;
    }
    
    _rowPositions[0] += offset;
    
    BOOL needToLoadHeight = isMovement || [tableView _hasEstimatedHeightForRow];
    if (needToLoadHeight || offset != 0) {
        for (NSInteger i = 0; i < _numberOfRows; ++i) {
            if (offset != 0) {
                _rowPositions[i + 1] += offset;
            }
            
            if (!needToLoadHeight) {
                if (offset == 0) {
                    break;
                } else {
                    continue;
                }
            }
            CGFloat differ = [tableView _updateGetRebuildCellDifferInSection:self.section atRow:i fromLastSection:lastSection withDistance:distance needToLoadHeight:&needToLoadHeight];
            if (differ != 0) {
                offset += differ;
                _rowPositions[i + 1] += differ;
            }
        }
    }
    
    self.endPos += offset;
    if (isMovement || [tableView _hasEstimatedHeightForFooter]) {
        [self _updateFooterForTableView:tableView fromLastSection:lastSection withOffset:distance isMovement:isMovement];
    }
}

// called only when needToDisplay is YES or offset isn't equal to 0
- (CGFloat)estimateForTableView:(MPTableView *)tableView atFirstRow:(NSInteger)firstRow withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay {
    self.startPos += offset;
    
    NSInteger lastSection = _section;
    
    CGFloat newHeaderHeight = 0;
    if (needToDisplay && _headerHeight && [tableView _hasEstimatedHeightForHeader]) {
        self.endPos += offset;
        newHeaderHeight = [tableView _estimatedGetSectionViewHeightWithType:MPSectionHeader inSection:self];
        self.endPos -= offset;
        if (newHeaderHeight >= 0) {
            offset += newHeaderHeight - _headerHeight;
            _headerHeight = newHeaderHeight;
        }
    }
    
    _rowPositions[0] += offset;
    
    BOOL needToLoadHeight = needToDisplay;
    for (NSInteger i = (newHeaderHeight < 0 ? firstRow : 0); i < _numberOfRows; ++i) {
        if (offset != 0) {
            _rowPositions[i + 1] += offset;
        }
        
        if (!needToLoadHeight) {
            if (offset == 0) {
                break;
            } else {
                continue;
            }
        }
        CGFloat differ = [tableView _estimatedDisplayCellInSection:lastSection atRow:i withOffset:offset needToLoadHeight:&needToLoadHeight];
        if (differ != 0) {
            offset += differ;
            _rowPositions[i + 1] += differ;
        }
    }
    
    self.endPos += offset;
    
    if (needToDisplay && _footerHeight && [tableView _hasEstimatedHeightForFooter]) {
        CGFloat footerHeight = [tableView _estimatedGetSectionViewHeightWithType:MPSectionFooter inSection:self];
        if (footerHeight >= 0) {
            CGFloat differ = footerHeight - _footerHeight;
            offset += differ;
            self.endPos += differ;
            _footerHeight = footerHeight;
        }
    }
    
    if (needToDisplay) {
        [tableView _estimatedDisplaySectionViewInSection:lastSection withType:MPSectionHeader];
        [tableView _estimatedDisplaySectionViewInSection:lastSection withType:MPSectionFooter];
    }
    
    return offset;
}

@end
