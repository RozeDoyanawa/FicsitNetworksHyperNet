-- Copyright (C) 2017 - DarkRoku12
-- Source: https://github.com/DarkRoku12/lua_sort
-- Licence: MIT
local MIN_MERGE = 32;



--
-- Copyright (c) 2009, 2013, Oracle and/or its affiliates. All rights reserved.
-- Copyright 2009 Google Inc.  All Rights Reserved.
-- ORACLE PROPRIETARY/CONFIDENTIAL. Use is subject to license terms.

-- A stable, adaptive, iterative mergesort that requires far fewer than
-- n lg(n) comparisons when running on partially sorted arrays, while
-- offering performance comparable to a traditional mergesort when run
-- on random arrays.  Like all proper mergesorts, this sort is stable and
-- runs O(n log n) time (worst case).  In the worst case, this sort requires
-- temporary storage space for n/2 object references in the best case,
-- it requires only a small constant amount of space.
--
-- This implementation was adapted from Tim Peters's list sort for
-- Python, which is described in detail here:
--
--   http:--svn.python.org/projects/python/trunk/Objects/listsort.txt
--
-- Tim's C code may be found here:
--
--   http:--svn.python.org/projects/python/trunk/Objects/listobject.c
--
-- The underlying techniques are described in this paper (and may have
-- even earlier origins):
--
--  "Optimistic Sorting and Information Theoretic Complexity"
--  Peter McIlroy
--  SODA (Fourth Annual ACM-SIAM Symposium on Discrete Algorithms),
--  pp 467-474, Austin, Texas, 25-27 January 1993.
--
-- While the API to this class consists solely of static methods, it is
-- (privately) instantiable a TimSort instance holds the state of an ongoing
-- sort, assuming the input array is large enough to warrant the full-blown
-- TimSort. Small arrays are sorted in place, using a binary insertion sort.
--
-- @author Josh Bloch


---@generic T:any
---@class TimSort
---@field MIN_GALLOP number When we get into galloping mode, we stay there until both runs win less
---                         often than MIN_GALLOP consecutive times.
---@field INITIAL_TMP_STORAGE_LENGTH number
---@field minGallop number
---@field c fun(a:any, b:any):number The comparator for this sort.
---@field a T[] The array being sorted.
---@field tmp T[]
---@field tmpBase number
---@field tmpLen number
---@field stackSize number
---@field runBase number[]
---@field runLen number[]
local TimSort = {}


        --This is the minimum sized sequence that will be merged.  Shorter
        --sequences will be lengthened by calling binarySort.  If the entire
        --array is less than this length, no merges will be performed.
        --
        --This constant should be a power of two.  It was 64 in Tim Peter's C
        --implementation, but 32 was empirically determined to work better in
        --this implementation.  In the unlikely event that you set this constant
        --to be a number that's not a power of two, you'll need to change the
        --@link #minRunLengthend computation.
        --
        --If you decrease this constant, you must change the stackLen
        --computation in the TimSort constructor, or you risk an
        --ArrayOutOfBounds exception.  See listsort.txt for a discussion
        --of the minimum stack length required as a function of the length
        --of the array being sorted and the minimum merge sequence length.

        --private static final int MIN_MERGE = 32


    ---When we get into galloping mode, we stay there until both runs win less
    ---often than MIN_GALLOP consecutive times.

--private static final int  MIN_GALLOP = 7


    ---This controls when we get *into* galloping mode.  It is initialized
    ---to MIN_GALLOP.  The mergeLo and mergeHi methods nudge it higher for
    ---random data, and lower for highly structured data.

--private int minGallop = MIN_GALLOP


    ---Maximum initial size of tmp array, which is used for merging.  The array
    ---can grow to accommodate demand.
    ---
    ---Unlike Tim's original C version, we do not allocate this much storage
    ---when sorting smaller arrays.  This change was required for performance.

  --  private static final int INITIAL_TMP_STORAGE_LENGTH = 256


---Creates a TimSort instance to maintain the state of an ongoing sort.
---
---@generic T:any
---@param a T[] the array to be sorted
---@param c fun(a:T, b:T):number comparator to determine the order of the sort
---@param work T[] a workspace array (slice)
---@param workBase number origin of usable space in work array
---@param workLen number usable size of work array
function TimSort.new(a, c, work, workBase, workLen)
    ---@type TimSort
    local this = {
        INITIAL_TMP_STORAGE_LENGTH = 256,
        MIN_GALLOP = 7,
        stackSize = 0,
        runBase = {},
        runLen = {},
    }

    this.minGallop = this.MIN_GALLOP
    this.a = a
    this.c = c

    setmetatable(this, TimSort)
    TimSort.__index = TimSort

    -- Allocate temp storage (which may be increased later if necessary)
    local len = #a
    local tlen = 0
    if (len < 2 * this.INITIAL_TMP_STORAGE_LENGTH) then
        tlen = len >> 1
    else
        tlen = this.INITIAL_TMP_STORAGE_LENGTH
    end
    if (work == nil or workLen < tlen or workBase + tlen > #work) then
        local newArray = { }
        for i=1,tlen do
            newArray[i] = 0
        end

        this.tmp = newArray
        this.tmpBase = 0
        this.tmpLen = tlen
    else
        this.tmp = work
        this.tmpBase = workBase
        this.tmpLen = workLen
    end

    --
    -- Allocate runs-to-be-merged stack (which cannot be expanded).  The
    -- stack length requirements are described in listsort.txt.  The C
    -- version always uses the same stack length (85), but this was
    -- measured to be too expensive when sorting "mid-sized" arrays (e.g.,
    -- 100 elements) in Java.  Therefore, we use smaller (but sufficiently
    -- large) stack lengths for smaller arrays.  The "magic numbers" in the
    -- computation below must be changed if MIN_MERGE is decreased.  See
    -- the MIN_MERGE declaration above for more information.
    -- The maximum value of 49 allows for an array up to length
    -- Integer.MAX_VALUE-4, if array is filled by the worst case stack size
    -- increasing scenario. More explanations are given in section 4 of:
    -- http:--envisage-project.eu/wp-content/uploads/2015/02/sorting.pdf

    local stackLen = 0
    if len <    120  then
        stackLen = 5
    elseif len < 1542 then
        stackLen = 10
    elseif len < 119151  then
        stackLen =  24
    else
        stackLen = 49
    end

    this.runBase = {}
    this.runLen = {}
    return this
end



---Returns the minimum acceptable run length for an array of the specified
---length. Natural runs shorter than this will be extended with
---@link #binarySortend.
---
---Roughly speaking, the computation is:
---
--- If n < MIN_MERGE, return n (it's too small to bother with fancy stuff).
--- Else if n is an exact power of 2, return MIN_MERGE/2.
--- Else return an int k, MIN_MERGE/2 <= k <= MIN_MERGE, such that n/k
---  is close to, but strictly less than, an exact power of 2.
---
---For the rationale, see listsort.txt.
---
---@param n number the length of the array to be sorted
---@return number the length of the minimum run to be merged
function minRunLength(n)
    assert (n >= 0)
    local r = 0      -- Becomes 1 if any 1 bits are shifted off
    while (n >= MIN_MERGE) do
        r = r | (n & 1)
        n = n >> 1
    end
    return n + r
end


---Pushes the specified run onto the pending-run stack.
---
---@param runBase number index of the first element in the run
---@param runLen  number the number of elements in the run
function TimSort:pushRun(runBase, runLen)
    self.runBase[self.stackSize] = runBase
    self.runLen[self.stackSize] = runLen
    self.stackSize = self.stackSize + 1
end


---Examines the stack of runs waiting to be merged and merges adjacent runs
---until the stack invariants are reestablished:
---
---    1. runLen[i - 3] > runLen[i - 2] + runLen[i - 1]
---    2. runLen[i - 2] > runLen[i - 1]
---
---This method is called each time a new run is pushed onto the stack,
---so the invariants are guaranteed to hold for i < stackSize upon
---entry to the method.
function TimSort:mergeCollapse()
    local q = 0;
    while (self.stackSize > 1) do
        local n = self.stackSize - 2
        if (n > 0 and self.runLen[n-1] <= self.runLen[n] + self.runLen[n+1]) then
            if (self.runLen[n - 1] < self.runLen[n + 1]) then
                n = n - 1
            end
            self:mergeAt(n)
        elseif (self.runLen[n] <= self.runLen[n + 1]) then
            self:mergeAt(n)
        else
            break -- Invariant is established
        end
        if q > 10 then
            error("")
        end
        q = q +1
    end
end

---Merges all runs on the stack until only one remains.  This method is
---called once, to complete the sort.
function TimSort:mergeForceCollapse()
    while (self.stackSize > 1) do
        local n = self.stackSize - 2
        if (n > 0 and self.runLen[n - 1] < self.runLen[n + 1]) then
            n = n - 1
        end
        self:mergeAt(n)
    end
end


---Merges the two runs at stack indices i and i+1.  Run i must be
---the penultimate or antepenultimate run on the stack.  In other words,
---i must be equal to stackSize-2 or stackSize-3.
---
---@param i number stack index of the first of the two runs to merge
function TimSort:mergeAt(i)
    assert (self.stackSize >= 2)
    assert (i >= 0)
    assert (i == self.stackSize - 2 or i == self.stackSize - 3)

    local base1 = self.runBase[i]
    local len1 = self.runLen[i]
    local base2 = self.runBase[i + 1]
    local len2 = self.runLen[i + 1]
    assert (len1 > 0 and len2 > 0)
    assert (base1 + len1 == base2)


    -- Record the length of the combined runs if i is the 3rd-last
    -- run now, also slide over the last run (which isn't involved
    --in this merge).  The current run (i+1) goes away in any case.

    self.runLen[i] = len1 + len2
    if (i == self.stackSize - 3) then
        self.runBase[i + 1] = self.runBase[i + 2]
        self.runLen[i + 1] = self.runLen[i + 2]
    end
    self.stackSize = self.stackSize - 1

    --
    --Find where the first element of run2 goes in run1. Prior elements
    --in run1 can be ignored (because they're already in place).

    local k = self:gallopRight(self.a[base2], self.a, base1, len1, 0, self.c)
    assert( k >= 0)
    base1 = base1 + k
    len1 =  len1 - k
    if (len1 == 0) then
        return
    end

    -- Find where the last element of run1 goes in run2. Subsequent elements
    -- in run2 can be ignored (because they're already in place).

    len2 = self:gallopLeft(self.a[base1 + len1 - 1], self.a, base2, len2, len2 - 1, self.c)
    assert (len2 >= 0)
    if (len2 == 0) then
        return
    end
    -- Merge remaining runs, using tmp array with min(len1, len2) elements
    if (len1 <= len2) then
        self:mergeLo(base1, len1, base2, len2)
    else
        self:mergeHi(base1, len1, base2, len2)
    end
end


---Locates the position at which to insert the specified key into the
---specified sorted range if the range contains an element equal to key,
---returns the index of the leftmost equal element.
---
---@generic T:any
---@param key T the key whose insertion point to search for
---@param a T[] the array in which to search
---@param base number the index of the first element in the range
---@param len number the length of the range must be > 0
---@param hint number the index at which to begin the search, 0 <= hint < n.
---    The closer hint is to the result, the faster this method will run.
---@param c fun(a:T, b:T):number the comparator used to order the range, and to search
---@return number the int k,  0 <= k <= n such that a[b + k - 1] < key <= a[b + k],
---   pretending that a[b - 1] is minus infinity and a[b + n] is infinity.
---   In other words, key belongs at index b + k or in other words,
---   the first k elements of a should precede key, and the last n - k
---   should follow it.
function TimSort:gallopLeft(key, a, base, len, hint, c)
    assert (len > 0 and hint >= 0 and hint < len)
    local lastOfs = 0
    local ofs = 1
    if (c(key, a[base + hint]) > 0) then
        -- Gallop right until a[base+hint+lastOfs] < key <= a[base+hint+ofs]
        local maxOfs = len - hint
        while (ofs < maxOfs and c(key, a[base + hint + ofs]) > 0) do
            lastOfs = ofs
            ofs = (ofs << 1) + 1
            if (ofs <= 0) then   -- int overflow
                ofs = maxOfs
            end
        end
        if (ofs > maxOfs) then
            ofs = maxOfs
        end
        -- Make offsets relative to base
        lastOfs = lastOfs + hint
        ofs = ofs + hint
    else  -- key <= a[base + hint]
        -- Gallop left until a[base+hint-ofs] < key <= a[base+hint-lastOfs]
        local maxOfs = hint + 1
        while (ofs < maxOfs and c(key, a[base + hint - ofs]) <= 0) do
            lastOfs = ofs
            ofs = (ofs << 1) + 1
            if (ofs <= 0) then   -- int overflow
                ofs = maxOfs
            end
        end
        if (ofs > maxOfs) then
            ofs = maxOfs
        end
        -- Make offsets relative to base
        local tmp = lastOfs
        lastOfs = hint - ofs
        ofs = hint - tmp
    end
    assert (-1 <= lastOfs and lastOfs < ofs and ofs <= len)

    --
    -- Now a[base+lastOfs] < key <= a[base+ofs], so key belongs somewhere
    -- to the right of lastOfs but no farther right than ofs.  Do a binary
    -- search, with invariant a[base + lastOfs - 1] < key <= a[base + ofs].

    lastOfs = lastOfs + 1
    while (lastOfs < ofs) do
        local m = lastOfs + ((ofs - lastOfs) >> 1)

        if (c.compare(key, a[base + m]) > 0) then
            lastOfs = m + 1  -- a[base + m] < key
        else
            ofs = m          -- key <= a[base + m]
        end
    end
    assert (lastOfs == ofs)    -- so a[base + ofs - 1] < key <= a[base + ofs]
    return ofs
end


---Like gallopLeft, except that if the range contains an element equal to
---key, gallopRight returns the index after the rightmost equal element.
---
---@generic T:any
---@param key T the key whose insertion point to search for
---@param a T[] the array in which to search
---@param base number the index of the first element in the range
---@param len number the length of the range must be > 0
---@param hint number the index at which to begin the search, 0 <= hint < n.
---    The closer hint is to the result, the faster this method will run.
---@param c fun(a:T, b:T):number the comparator used to order the range, and to search
---@return number the int k,  0 <= k <= n such that a[b + k - 1] <= key < a[b + k]
function TimSort:gallopRight(key, a, base, len, hint, c)
    assert(len > 0 and hint >= 0 and hint < len)

    local ofs = 1
    local lastOfs = 0
    if (c(key, a[base + hint]) < 0) then
        -- Gallop left until a[b+hint - ofs] <= key < a[b+hint - lastOfs]
        local maxOfs = hint + 1
        while (ofs < maxOfs and c(key, a[base + hint - ofs]) < 0) do
            lastOfs = ofs
            ofs = (ofs << 1) + 1
            if (ofs <= 0) then   -- int overflow
                ofs = maxOfs
            end
        end
        if (ofs > maxOfs) then
            ofs = maxOfs
        end

        -- Make offsets relative to b
        local tmp = lastOfs
        lastOfs = hint - ofs
        ofs = hint - tmp
    else  -- a[b + hint] <= key
        -- Gallop right until a[b+hint + lastOfs] <= key < a[b+hint + ofs]
        local maxOfs = len - hint
        while (ofs < maxOfs and c(key, a[base + hint + ofs]) >= 0) do
            lastOfs = ofs
            ofs = (ofs << 1) + 1
            if (ofs <= 0) then   -- int overflow
                ofs = maxOfs
            end
        end
        if (ofs > maxOfs) then
            ofs = maxOfs
        end
        -- Make offsets relative to b
        lastOfs = lastOfs + hint
        ofs = ofs + hint
    end
    assert(-1 <= lastOfs and lastOfs < ofs and ofs <= len)

    --
    -- Now a[b + lastOfs] <= key < a[b + ofs], so key belongs somewhere to
    -- the right of lastOfs but no farther right than ofs.  Do a binary
    -- search, with invariant a[b + lastOfs - 1] <= key < a[b + ofs].

    lastOfs = lastOfs + 1
    while (lastOfs < ofs) do
        local m = lastOfs + ((ofs - lastOfs) >> 1)

        if (c(key, a[base + m]) < 0) then
            ofs = m          -- key < a[b + m]
        else
            lastOfs = m + 1  -- a[b + m] <= key
        end
    end
    assert(lastOfs == ofs)    -- so a[b + ofs - 1] <= key < a[b + ofs]
    return ofs
end


---Merges two adjacent runs in place, in a stable fashion.  The first
---element of the first run must be greater than the first element of the
---second run (a[base1] > a[base2]), and the last element of the first run
---(a[base1 + len1-1]) must be greater than all elements of the second run.
---
---For performance, this method should be called only when len1 <= len2
---its twin, mergeHi should be called if len1 >= len2.  (Either method
---may be called if len1 == len2.)
---
---@param base1 number index of first element in first run to be merged
---@param len1  number length of first run to be merged (must be > 0)
---@param base2 number index of first element in second run to be merged
---       (must be aBase + aLen)
---@param len2  number length of second run to be merged (must be > 0)
function TimSort:mergeLo(base1, len1, base2, len2)
    assert (len1 > 0 and len2 > 0 and base1 + len1 == base2)

    -- Copy first run into temp array
    local a = self.a -- For performance
    local tmp = self:ensureCapacity(len1)
    local cursor1 = self.tmpBase -- Indexes into tmp array
    local cursor2 = base2   -- Indexes int a
    local dest = base1      -- Indexes int a
    arraycopy(a, base1, tmp, cursor1, len1)

    -- Move first element of second run and deal with degenerate cases
    a[dest] = a[cursor2]
    dest = dest + 1
    cursor2 = cursor2 + 1
    len2 = len2 - 1
    if (len2 == 0) then
        arraycopy(tmp, cursor1, a, dest, len1)
        return
    end
    if (len1 == 1) then
        arraycopy(a, cursor2, a, dest, len2)
        a[dest + len2] = tmp[cursor1] -- Last elt of run 1 to end of merge
        return
    end

    local c = self.c  -- Use local variable for performance
    local minGallop = self.minGallop    --  "    "       "     "      "

    while (true) do
        local count1 = 0 -- Number of times in a row that first run won
        local count2 = 0 -- Number of times in a row that second run won

        --
        -- Do the straightforward thing until (if ever) one run starts
        -- winning consistently.

        repeat
            assert(len1 > 1 and len2 > 0)
            if (c(a[cursor2], tmp[cursor1]) < 0) then
                a[dest] = a[cursor2]
                dest = dest + 1
                cursor2 = cursor2 + 1
                count1 = 0
                if (len2 == 0) then
                    goto outer
                end
            else
                a[dest] = tmp[cursor1]
                dest = dest + 1
                cursor1 = cursor1 + 1
                count1 = count1 + 1
                count2 = 0
                if (len1 == 1) then
                    goto outer
                end
            end
        until not ((count1 | count2) < minGallop)

        --
        -- One run is winning so consistently that galloping may be a
        -- huge win. So try that, and continue galloping until (if ever)
        -- neither run appears to be winning consistently anymore.

        repeat
            assert (len1 > 1 and len2 > 0)
            count1 = self:gallopRight(a[cursor2], tmp, cursor1, len1, 0, c)
            if (count1 ~= 0) then
                arraycopy(tmp, cursor1, a, dest, count1)
                dest = dest + count1
                cursor1 = cursor1 + count1
                len1 = len1 - count1
                if (len1 <= 1) then -- len1 == 1 || len1 == 0
                    goto outer
                end
            end
            a[dest] = a[cursor2]
            len2 = len2 - 1
            if (len2 == 0) then
                goto outer
            end
            count2 = self:gallopLeft(tmp[cursor1], a, cursor2, len2, 0, c)
            if (count2 ~= 0) then
                arraycopy(a, cursor2, a, dest, count2)
                dest = dest + count2
                cursor2 = cursor2 + count2
                len2 = len2 - count2
                if (len2 == 0 ) then
                    goto outer
                end
            end
            a[dest] = tmp[cursor1]
            dest = dest + 1
            cursor1 = cursor1 + 1
            len1 = len1 - 1
            if (len1 == 1) then
                goto outer
            end
            minGallop = minGallop - 1
        until not (count1 >= self.MIN_GALLOP | count2 >= self.MIN_GALLOP)
        if (minGallop < 0) then
            minGallop = 0
        end
        minGallop = minGallop + 2  -- Penalize for leaving gallop mode
    end  -- End of "outer" loop
    ::outer::
    if minGallop < 1 then
        self.minGallop = 1
    else
        self.minGallop = minGallop  -- Write back to field
    end
    if (len1 == 1) then
        assert (len2 > 0)
        arraycopy(a, cursor2, a, dest, len2)
        a[dest + len2] = tmp[cursor1] --  Last elt of run 1 to end of merge
    elseif (len1 == 0) then
        error (
            "IllegalArgumentException: Comparison method violates its general contract!")
    else
        assert( len2 == 0)
        assert(len1 > 1)
        arraycopy(tmp, cursor1, a, dest, len1)
    end
end



---Like mergeLo, except that this method should be called only if
---len1 >= len2 mergeLo should be called if len1 <= len2.  (Either method
---may be called if len1 == len2.)
---@param base1 number index of first element in first run to be merged
---@param len1  number length of first run to be merged (must be > 0)
---@param base2 number index of first element in second run to be merged
---                    (must be aBase + aLen)
---@param len2  number length of second run to be merged (must be > 0)
function TimSort:mergeHi(base1, len1, base2, len2)
    assert(len1 > 0 and len2 > 0 and base1 + len1 == base2)

    -- Copy second run into temp array
    local a = self.a -- For performance
    local tmp = self:ensureCapacity(len2)
    local tmpBase = self.tmpBase
    arraycopy(a, base2, tmp, tmpBase, len2)

    local cursor1 = base1 + len1 - 1  -- Indexes into a
    local cursor2 = tmpBase + len2 - 1 -- Indexes into tmp array
    local dest = base2 + len2 - 1     -- Indexes into a

    -- Move last element of first run and deal with degenerate cases
    a[dest] = a[cursor1]
    dest = dest - 1
    cursor1 = cursor1 - 1
    len1 = len1 - 1
    if (len1 == 0) then
        arraycopy(tmp, tmpBase, a, dest - (len2 - 1), len2)
        return
    end
    if (len2 == 1) then
        dest = dest - len1
        cursor1 = cursor1 - len1
        arraycopy(a, cursor1 + 1, a, dest + 1, len1)
        a[dest] = tmp[cursor2]
        return
    end

    local c = self.c  -- Use local variable for performance
    local minGallop = self.minGallop    --  "    "       "     "      "

    while (true) do
        local count1 = 0 -- Number of times in a row that first run won
        local count2 = 0 -- Number of times in a row that second run won

        --
        -- Do the straightforward thing until (if ever) one run
        -- appears to win consistently.

        repeat
            assert(len1 > 0 and len2 > 1)
            if (c(tmp[cursor2], a[cursor1]) < 0) then
                a[dest] = a[cursor1]
                dest = dest - 1
                cursor1 = cursor1 - 1
                count1 = count1 + 1
                count2 = 0
                len1 = len1 - 1
                if (len1 == 0) then
                    goto outer
                end
            else
                a[dest] = tmp[cursor2]
                cursor2 = cursor2 - 1
                dest = dest - 1
                count2 = count2 + 1
                count1 = 0
                len2 = len2 - 1
                if (len2 == 1) then
                    goto outer
                end
            end
        until not ((count1 | count2) < minGallop)

        --
        -- One run is winning so consistently that galloping may be a
        -- huge win. So try that, and continue galloping until (if ever)
        -- neither run appears to be winning consistently anymore.

        repeat
            assert (len1 > 0 and len2 > 1)
            count1 = len1 - self:gallopRight(tmp[cursor2], a, base1, len1, len1 - 1, c)
            if (count1 ~= 0) then
                dest = dest - count1
                cursor1 = count1 - count1
                len1 = len1 - count1
                arraycopy(a, cursor1 + 1, a, dest + 1, count1)
                if (len1 == 0) then
                    goto outer
                end
            end
            a[dest] = tmp[cursor2]
            dest = dest - 1
            cursor2 = cursor2 - 1
            len2 = len2 - 1
            if (len2 == 1) then
                goto outer
            end
            count2 = len2 - self:gallopLeft(a[cursor1], tmp, tmpBase, len2, len2 - 1, c)
            if (count2 ~= 0) then
                dest = dest - count2
                cursor2 = cursor2 - count2
                len2 = len2 - count2
                arraycopy(tmp, cursor2 + 1, a, dest + 1, count2)
                if (len2 <= 1) then  -- len2 == 1 || len2 == 0
                    goto outer
                end
            end
            a[dest] = a[cursor1]
            dest = dest - 1
            cursor1 = cursor1 - 1
            len1 = len1 - 1
            if (len1 == 0) then
                goto outer
            end
            minGallop = minGallop - 1
        until not (count1 >= self.MIN_GALLOP | count2 >= self.MIN_GALLOP)
        if (minGallop < 0) then
            minGallop = 0
        end
        minGallop = minGallop + 2  -- Penalize for leaving gallop mode
    end  -- End of "outer" loop
    ::outer::
    self.minGallop = minGallop  -- Write back to field
    if minGallop < 1 then
        self.minGallop = 1
    end

    if (len2 == 1) then
        assert(len1 > 0)
        dest = dest - len1
        cursor1 = cursor1 - len1
        arraycopy(a, cursor1 + 1, a, dest + 1, len1)
        a[dest] = tmp[cursor2]  -- Move first elt of run2 to front of merge
    elseif (len2 == 0) then
        error(
                "IllegalArgumentException: Comparison method violates its general contract!")
    else
        assert(len1 == 0)
        assert(len2 > 0)
        arraycopy(tmp, tmpBase, a, dest - (len2 - 1), len2)
    end
end


---Ensures that the external array tmp has at least the specified
---number of elements, increasing its size if necessary.  The size
---increases exponentially to ensure amortized linear time complexity.
--
---@generic T:any
---@param minCapacity number the minimum required capacity of the tmp array
---@return T[] tmp, whether or not it grew
function TimSort:ensureCapacity(minCapacity)
    if (self.tmpLen < minCapacity) then
        -- Compute smallest power of 2 > minCapacity
        local newSize = minCapacity
        newSize = newSize | (newSize >> 1)
        newSize = newSize | (newSize >> 2)
        newSize = newSize | (newSize >> 4)
        newSize = newSize | (newSize >> 8)
        newSize = newSize | (newSize >> 16)
        newSize = newSize + 1

        if (newSize < 0) then -- Not bloody likely!
            newSize = minCapacity
        else
            newSize = math.min(newSize, #self.a >> 1)
        end

        local newArray = {}
        for i = 1, newSize do
            newArray[i] = nil
        end
        self.tmp = newArray
        self.tmpLen = newSize
        self.tmpBase = 0
    end
    return self.tmp
end




















-- Stack slot #1 = t.
local function set2( t , i , j , ival , jval )
    t[ i ] = ival ; -- lua_rawseti(L, 1, i);
    t[ j ] = jval ; -- lua_rawseti(L, 1, j);
end

local function sort_comp( a , b , comp )

    if comp then
        return comp( a , b )
    end

    return a < b ;
end

local auxsort ;

---@generic T:any
---@param a T[]
---@param lo number
---@param hi number
function reverseRange(a, lo, hi)
    hi = hi - 1;
    while lo < hi do
        local t = a[lo];
        a[lo] = a[hi];
        lo = lo + 1
        a[hi] = t;
        hi = hi - 1
    end
end

---@generic T
---@param a T[]
---@param lo number
---@param hi number
---@param c fun(a:T, b:T):number
---@return number
function countRunAndMakeAscending(a, lo, hi, c)
    assert(lo < hi)
    local runHi = lo + 1
    if (runHi == hi) then
        return 1;
    end

    -- Find end of run, and reverse range if descending
    --print(runHi, a[runHi], lo, a[lo])
    if (c(a[runHi], a[lo]) < 0) then -- Descending
        runHi = runHi + 1
        --print(runHi, a[runHi], a[runHi - 1])
        while (runHi < hi and c(a[runHi], a[runHi - 1]) < 0) do
            runHi = runHi + 1;
        end
        reverseRange(a, lo, runHi);
    else                               -- Ascending
        runHi = runHi + 1
        --print(runHi, a[runHi], a[runHi - 1])
        while (runHi < hi and c(a[runHi], a[runHi - 1]) >= 0) do
            runHi = runHi + 1;
        end
    end
    --print(runHi, lo)
    return runHi - lo;
end


---@generic T:any
---@param src T[]
---@param srcPos number
---@param dst T[]
---@param dstPos number
---@param length number
function arraycopy(src, srcPos, dst, dstPos, length)
    assert(srcPos >= 0 )
    assert(dstPos >= 0 )
    assert(length >= 0 )
    assert(srcPos + length <= #src + 1)
    assert(dstPos + length <= #dst + 1)

    for i = length - 1, 0, -1 do
        dst[i + dstPos] = src[i + srcPos]
    end
end

---@generic T
---@param a T[]
---@param lo number
---@param hi number
---@param start number
---@param c fun(a:T, b:T):number
function binarySort(a, lo, hi, start, c)
    assert(lo <= start or start <= hi)
    if (start == lo) then
        start = start + 1;
    end
    for start2 = start,hi - 1,1 do
        --for ( ; start < hi; start++) do
        local pivot = a[start2];

        -- Set left (and right) to the index where a[start] (pivot) belongs
        local left = lo;
        local right = start2;
        assert(left <= right);
        --
        -- Invariants:
        --   pivot >= all in [lo, left).
        --   pivot <  all in [right, start).
        --
        while (left < right) do
            local mid = (left + right) >> 1;
            local q = c(pivot, a[mid])
            --print("res", q)
            if (q < 0) then
                right = mid;
            else
                left = mid + 1;
            end
        end
        assert(left == right);

        --
        -- The invariants still hold: pivot >= all in [lo, left) and
        -- pivot < all in [left, start), so pivot belongs at left.  Note
        -- that if there are elements equal to pivot, left points to the
        -- first slot after them -- that's why this sort is stable.
        -- Slide elements over to make room for pivot.
        --
        local n = start2 - left;  -- The number of elements to move
        -- Switch is just an optimization for arraycopy in default case
        --printArray(a)
        --print("left=",left, "n=", n, "#a=", #a, "start2=",start2)
        arraycopy(a, left, a, left + 1, n);
        a[left] = pivot;
    end
end


---@generic T
---@param a T[]
---@param lo number
---@param hi number
---@param c fun(a:T, b:T):number
---@param work T[]
---@param workBase number
---@param workLen number
---@return T[]
function sort(a, lo, hi, c, work, workBase, workLen)
    assert (c ~= nil and a ~= nil and lo >= 0 and lo <= hi and hi <= #a + 1)

    local nRemaining  = hi - lo;
    if nRemaining < 2 then
        return  -- Arrays of size 0 and 1 are always sorted

    end

    -- If array is small, do a "mini-TimSort" with no merges
    if nRemaining < MIN_MERGE  then
        local initRunLen = countRunAndMakeAscending(a, lo, hi, c);
        binarySort(a, lo, hi, lo + initRunLen, c);
        return;
    end

    --
    -- March over the array once, left to right, finding natural runs,
    -- extending short natural runs to minRun elements, and merging runs
    -- to maintain stack invariant.
    --
    local ts = TimSort.new(a, c, work, workBase, workLen);
    local minRun = minRunLength(nRemaining);
    repeat
        -- Identify next run
        local runLen = countRunAndMakeAscending(a, lo, hi, c);
        -- If run is short, extend to min(minRun, nRemaining)
        if runLen < minRun then
            local force = 0
            if nRemaining <= minRun then
                force = nRemaining
            else
                force = minRun
            end
            binarySort(a, lo, lo + force, lo + runLen, c);
            runLen = force;
        end

        -- Push run onto pending-run stack, and maybe merge
        ts:pushRun(lo, runLen);
        ts:mergeCollapse();

        -- Advance to find next run
        lo = lo + runLen;
        nRemaining = nRemaining - runLen;
    until (nRemaining == 0)

    -- Merge all remaining runs to complete sort
    assert(lo == hi);
    ts:mergeForceCollapse();
    assert(ts.stackSize == 1);
end

-- sort function.
return function( a , c )

    assert( type( a ) == "table" )

    if c then
        assert( type( c ) == "function" )
    end

    local a2 = {}
    for i = 1, #a + 1 do
        a2[i-1] = a[i]
    end

    return sort(a, 1, #a + 1, c, nil, 0, 0);

end