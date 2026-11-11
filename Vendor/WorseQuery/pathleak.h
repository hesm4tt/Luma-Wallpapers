//
//  pathleak.h
//  worse_query
//
//  Created by Taj C on 9/2/26.
//

/*
     pathleak - The dumbest arbitrary path enumeration.
     Copyright (C) 2026 Taj C (forcequit)

     This program is free software: you can redistribute it and/or modify
     it under the terms of the GNU General Public License as published by
     the Free Software Foundation, either version 3 of the License, or
     (at your option) any later version.

     This program is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
     GNU General Public License for more details.

     You should have received a copy of the GNU General Public License
     along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#ifndef pathleak_h
#define pathleak_h

#import <Foundation/Foundation.h>

// Returns a normalized direct child of the requested directory, or nil.
NSString * _Nullable pathleak_direct_child(NSString * _Nonnull candidate, NSString * _Nonnull directory);
NSArray<NSString *> * _Nullable pathleak(NSString * _Nonnull filter, uint64_t max_inode);
NSArray<NSString *> * _Nullable pathleak_with_progress(NSString * _Nonnull filter, uint64_t max_inode, void (^ _Nullable progress)(uint64_t, uint64_t));

#endif /* pathleak_h */
