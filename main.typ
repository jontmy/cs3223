#import "template.typ": *
#show: project

#import "@preview/ctheorems:1.1.2": *
#show: thmrules

#let theorem = thmbox("theorem", "Theorem", fill: rgb("#eeffee"), base_level: 1, 
padding: (top: 0.1em, bottom: 0.1em), inset: 0.8em, radius: 0.3em)

= Hash-based indexing

== Dynamic hashing
Assume initial file size of $N_0$ buckets.
Let $N_i = 2^i N_0$ be the file size at the beginning of round $i$.

=== Insertion
`next` specifies the next bucket to be split, and is initialized to 0 at the start of each round.

Buckets are split when any bucket overflows.

=== Deletion

==== Case 1
`next` $> 0$. Decrement `next`.

==== Case 2
`next` $> 0$ and `level` $> 0$. Update `next` to point to the last bucket in the previous level $B_(N_("level"-1)-1)$. Decrement `level` by 1.

=== Performance
1 disk I/O unless bucket has overflow pages,
on average 1.2 disk I/O,
worst case linear with the number of data entries.

== Extendible hashing
Let $g$ be the _global depth_. The directory has $2^g$ entries;
each entry is $g$-bits and maintains a pointer to a bucket.
_Corresponding entries_ differ only in the $g^"th"$ most significant bit.

Each bucket maintains a _local depth_ $l #sym.in [0, g]$;
each entry $e$ has the same $l$ least significant bits of $h(e)$.

=== Insertion
If a bucket has free space, insert the elmeent into the bucket.
Otherwise, handle _bucket overflow_ as follows.

==== Case 1
When $l = g$.
Double directory size, increment both $g$ and $l$ by 1.
All new directory entries except the entry for the split image point to the same bucket as its corresponding entry.
Then for any bucket, $2^(d-l)$ directory entries point to it.
Redistribute entries between split bucket and split image.

==== Case 2
When $l < g$.
Do not expand directory.
Move elements which do not belong in the split bucket to the split image.
Do not move elements within the split bucket (free spaces are acceptable).

=== Deletion
Let $B_i$ be the bucket with the element to be deleted and $B_j$ its split image.
$B_i$ and $B_j$ can be merged if $l_i = l_j$ and their elements can fit within a single bucket.

If every pair of corresponding entries point to the same bucket, halve the directory size and decrement $d$ by 1.

=== Performance
$<= 2 "disk I/Os"$ for equality selection, $<= 1$ if directory fits in main memory.
Use _overflow pages_ when the number of collisions exceeds page capacity.

= Sorting
Used by queries with `ORDER BY`, bulk loading $B^+$-tree index, projection, and joins.
Assuming data cannot fit in main memory and there is no $B^+$-tree index (otherwise a sequential scan suffices).

== External merge sort
Let $N$ be the file size in number of pages, and $B$ in-memory buffer pages are available.

==== Pass 0
Read and sort $B$ pages at a time for a total of $N_0 = ceil(N/B)$ sorted runs.

==== Pass $i$
Because random I/O is slower than sequential I/O we read and write blocks of in $b$ buffer pages when merging.

Let $F = floor((B-b)/b) = floor(B/b) - 1$ be the number of runs that can be merged in each pass.
Without the blocked I/O optimization, $b = 1$.

Therefore $1 <= i <= ceil(log_(F)N_0)$ using an $F$-way merge by allocating 1 block of $b$ pages for the output and $B - b$ pages for the input.

=== Performance
Each pass reads $N$ pages, then writes $N$ pages. This incurs a total of $2N (ceil(log_(F)N_0) + 1)$ disk I/Os.

There is no fixed formula to derive $b$ — it must be determined experimentally.

= Selection
$sigma_(p)(R)$ selects the rows from a relation $R$ satsifying a selection predicate $p$.
The selectivity of an access path (i.e. table scan, index scan, or index intersection) is inversely related to the total number of pages retrived to access the relevant records.

=== Covering indexes

An index $I$ is a _covering index_ for a query $Q$ if all attributes referenced in Q are part of the key or include columns of `CREATE INDEX ... ON [key] INCLUDE [attrs]`.

$Q$ can therefore be evaluated using $I$ without any RID lookup in an _index-only plan_.

=== Conjunctive normal form (CNF) predicates

/ Term: $R.A op C$ or $R.A_i op R.A_j$.
/ Conjunct: 1 or more terms connected by $or$.
/ CNF predicate: 1 or more conjuncts connected by $and$.

A conjunct is _disjunctive_ if it contains $or$.
Given a $B^+$-tree index $I$ and a non-disjunctive CNF predicate $p$, $I "matches" p$ if these hold:

$p$ has the form $(K_1 = c_1) and ... and (K_(i-1) = c_(i-1)) and (K_i op C_i)$, $i in [1, n]$,
$(K_1, ..., K_i)$ is a prefix of the key of $I$, and
if there exists at most one non-equality $op$, it must be the last attribute of the prefix, i.e., $K_i$.

Given a hash index $I$, $I "matches" p$, if, in addition to the above, there are no non-equality operators.

/ Primary conjunct: The subset of conjuncts in $p$ that matches $I$.
/ Covered conjunct: The subset of conjuncts in $p$ where all attributes appear in the key or include columns of $I$.

Primary conjuncts are a subset of covered conjuncts.

== Index evaluation

/ $r$: a relational algebra expression.
/ $|r|$: number of _pages_ in the output of $r$.
/ $||r||$: number of _tuples_ in the output of $r$.
/ $b_d$: number of _data records_ that can fit on a page.
/ $b_i$: number of _data entries_ that can fit on a page.
/ $F$: average fanout of $B^+$-tree index (i.e., number of pointers to child nodes).
/ $h$: height of B+-tree index (i.e., number of levels of internal nodes)
/ $B$: number of available buffer pages

For a format-2 index on a table $R$, $h = ceil(log_F (ceil((||R||)/b_i)))$

=== *$B^+$*-tree index evaluation
Given a CNF predicate $p$, let $p'$ be its primary conjuncts and $p_c$ its convered conjuncts.
Then, the total I/O cost is as follows:

$ "total I/O cost" = "cost"_"internal" + "cost"_"leaf" + "cost"_"rid" $

$"cost"_"internal"$ is the cost to navigate internal nodes to locate the first leaf page:

$ "cost"_"internal" = cases(
  ceil( log_F (ceil((||R||)/b_d)) ) "if" l "is a format-1 index",
  ceil( log_F (ceil((||R||)/b_i)) ) "otherwise"
) $

$"cost"_"leaf"$ is the cost to scan leaf pages to access all qualifying data entries:

$ "cost"_"leaf" = cases(
  ceil( (||sigma_(p') (R)||) / b_d ) "if" l "is a format-1 index",
  ceil( (||sigma_(p') (R)||) / b_i ) "otherwise"
) $

$"cost"_"rid"$ is the cost to retrieve qualified data records via RID lookups:
$ "cost"_"leaf" = cases(
  0 "if" l "is a covering or format-1 index",
  ||sigma_(p_c) (R)|| "otherwise"
) $

$"cost"_"rid"$ is also the worse case because it assumes every data record resides on a different data page.

It may be beneficial to sort the RIDs before retrieving data records, as it prevents multiple reads of the same data page when they are evicted from the buffer pool each time, in which case:

$ ceil( (||sigma_p_c (R)||)/b_d ) <= "cost"_"rid" <= min(||sigma_p_c (R)||, |R|)$

=== Hash index evaluation
Unlike the $B^+$ tree index, a hash index has no internal nodes, thus:

$ "total I/O cost" = "cost"_"leaf" + "cost"_"rid" $

= Projection
$pi_L (R)$ projects columns given by list $L$ from relation $R$, eliminating duplicates. $pi^*_L (R)$ preserves duplicates.

If there exists an index with all attributes in $L$, an index scan suffices.

== Sort-based projection

Extract attributes $L$ from records.
  cost to scan records = $|R|$
  cost to output temporary result = $|pi^*_L (R)|$
Sort records using attributes L as the sort key.
  cost to sort records = $2 abs(pi^*_L (R)) (log_m (N_0) + 1) $, where $m$ is the merge factor
Remove duplicates.
  cost to scan records = $|pi^*_L (R)|$

== Hash-based projection
If a hash table $T$ fits in main memory, trivially, the I/O cost is $abs(R)$,
but if it doesn't apply a divide-and-conquer approach as follows:

==== Partitioning
Using 1 input buffer page and $B - 1$ output pages, read $R$ one page at a time,
and for each tuple $t$:

project attributes on $t$ to get $t'$,
hash $t'$ with hash function $h$ to determine the output buffer, and
flush output buffer to disk when it is full.

==== Duplicate elimination
Using 1 input buffer page and $B - 1$ pages for the hash table, read $pi^*_L (R_i)$ one page at a time,
and for each tuple $t$:

hash $t$ into bucket $B_j$ with $h'$ where $h != h'$, and
insert $t$ into $B_j$ if $t in.not B_j$.

=== Performance
To avoid partition overflow (when the hash table for $pi^*_L (R_i)$ cannot fit in main memory),
assuming a uniform distribution of $h(t) forall t in R$, B needs to be large relative to $abs(R)$:

$ B > sqrt(f times abs( pi^*_L (R) )), " where" f = "fudge factor" $

Without partition overflow, the total I/O cost is as follows:
$ "cost" = abs(R) + abs(pi^*_L (R))_"partitioning" + abs(pi^*_L (R))_"duplicate elimination" $

This is the same as sort-based projection (but sort-based output is sorted).


= Joining
Given a join $R join_theta S$, R is the outer relation and S the inner relation.

== Iteration-based joins

==== Tuple-based nested loop join
A double `for` loop over R and S has an I/O cost of $abs(R) + ||R|| times abs(S)$.

==== Page-based nested loop join
A quadruple `for` loop over $P_R in R$, $P_S in S$, $r in P_R$, then $s in P_S$
has an I/O cost of $abs(R) + |R| times abs(S)$.

==== Block nested loop join
Exploits buffer space to minimize I/O. Allocate one page for $S$, one page for output, and $B - 2$ pages for $R$. Assume $abs(R) <= abs(S)$.

Loop over $B - 2$ pages of $R$ at a time, $P_S in S$, $r in R$, then $s in S$.
This reduces the number of scans needed for the inner table $S$, which brings I/O cost down to $abs(R) + (|R|)/(B-2) times abs(S)$.

== Index nested loop join
For a join $R join_theta_A S$, if there exists a $B^+$-tree index on $S.A$,
then $forall r in R$, use the index on $S$ with $r$ to find matching tuples.

=== Performance
Assume uniform distribution such that each $r in R$ joins with $ceil( (||S||)/(||pi_B_j (S)||) )$ tuples in S.

The total I/O cost is the sum of the following:
- scan R: $abs(R)$
- join each $r in R$ with each $s in S$: $||R|| times (J_"internal" + J_"leaf")$
  - $J_"internal" = log_F (ceil( (||S||)/b_d ))$
  - $J_"leaf" = ceil( (||S||)/(b_d ||pi_B_j (S)||) )$

== Sort-merge join
Let $R$ be the smaller relation, and $S$ the larger relation.
Sort both $R$ and $S$.
Forward scan $R$ and $S$ to find matching tuples, rewinding the $S$ pointer for each duplicate value in $R$.

$
"I/O cost" = & underbrace(2 abs(R) (log_m (N_R) + 1), "cost to sort R") + underbrace(2 abs(S) (log_m (N_S) + 1), "cost to sort S") \ & + underbrace(abs(R) + ||R|| times abs(S), "cost to merge")
$

=== Optimization
Merging the sorted runs into a single run before joining is redundant.

When $B > sqrt(2 abs(S))$, use one pass to create the sorted runs, and another pass to merge and join the sorted runs.

$
"I/O cost" = underbrace(2 times (abs(R) + abs(S)), "pass 0") + underbrace((abs(R) + abs(S)), "pass 1") = 3 times (abs(R) + abs(S))
$

== Grace hash join
Let $R$, the smaller relation, be known as the _build relation_, and $S$, the larger relation, be known as the _probe relation_.

With $k = B - 1$ buffers (one page for  input), partition $R$ and $S$ into $R_1, R_2, ..., R_k$ and $S_1, S_2, ..., S_k$
using a hash function $h$.

For each partition $R_i$ of $R$, build a hash table from $R_i$,
using a different hash function $h'$, and assuming it can fit in memory.

For each tuple $s$ in $S_i$, for each tuple $r$ in bucket $h'(s)$, if $r = s$, then output $(r, s)$.

$
"I/O cost" = underbrace(2 times (abs(R) + abs(S)), "partitioning") + underbrace((abs(R) + abs(S)), "probing") = 3 times (abs(R) + abs(S))
$

=== Partition overflow
The size of the hash table for $R_i$ is $(f times abs(R)) / (B - 1)$, where $f$ is some fudge factor.

We assumed that $B > (f times abs(R)) / (B - 1) + 2 > sqrt(f times abs(R))$ (+1 for one input buffer for $S_i$ and +1 for one output buffer when probing).

If this is not the case, recursively apply partitioning to overflow partitions.

== Cost estimation
For a query $q = sigma_p (e)$ where $p = t_1 and t_2 and ... and t_n$ and $e = R_1 times R_2 times ... times R_m$,
each term $t_i$ potentially filters out tuples in $e$.

The _reduction factor_ is the fraction of tuples in $e$ that satisfy $t_i$, i.e.

$
"reduction factor," "rf"(t_i) = (||sigma_(t_i)(e)||)/(||e||) \
||e|| = product_(i=1)^m ||R_i|| = R_1 times R_2 times ... times R_m \
||q|| approx ||e|| times product_(i=1)^n "rf"(t_i)
$

=== Join selectivity
Consider $R join_(R.A = S.B) S$.
Then $"rf"(R.A = S.B) = (||R join_(R.A = S.B) S||)/(||R|| times ||S||)$.

To estimate the reduction factor,
assume $||pi_A (R)|| <= ||pi_B (S)||$, then $ pi_A (R) subset.eq pi_B (S)$ (the inclusion assumption),
such that every $R$-tuple joins with some $S$-tuple.

Also assume attribute values are uniformly distributed (the uniformity assumption),
so each $R$-tuple joins with $(||S||)/(||pi_B (S)||)$ S-tuples.

$
||Q|| approx ||R|| times (||S||)/(||pi_B (S)||) \
"rf"(R.A = S.B) approx 1/max(||pi_A (R)||, ||pi_b (S)||)
$

=== Estimation with histograms
In equiwidth histograms, each bucket has an almost equal number of _values_,
while in equidepth histograms each bucket has almost equal number of _tuples_.

The boundary values of buckets may overlap only in equidepth histograms, e.g. $[2, 5], [5, 7]$.

==== MCV
Keep track of the frequencies of the top $k$ most common values, and exclude these
from the histrogram buckets.

= Transactions
#let read(rel, obj) = {
  $R_(rel) (obj)$
}

#let write(rel, obj) = {
  $W_(rel) (obj)$
}

#let commit(rel) = {
  $"Commit"_(rel)$
}

#let abort(rel) = {
  $"Abort"_(rel)$
}

/ Atomicity: Either all or none of the actions of a Tx happen.
/ Consistency: If each Tx is consistent, the DB starts consistent, and ends consistent.
/ Isolation: Execution of one Tx is isolated from other Txs.
/ Durability: If a Tx commits, its effects persist.

== Transaction management
The concurrency control manager ensures isolation.

=== View serializable schedules (VSS)
$T_j "reads" O "from" T_i$ if the last write action on $O$ before $read(j, O)$ is $write(i, O)$.
$T_j "reads from" T_i$ if $T_j$ has read some object $O$ from $T_i$.

$T_i$ performs the final write on $O$ in a schedule $S$ if the last write action on $O$ in $S$ is $write(i, O)$.

A schedule $S$ is a VSS if $S$ is view equivalent to some serial schedule $S'$ (no interleaved Txs), satisfying all of the following:

+ If $T_i$ reads $O$ from $T_j$ in $S$, then $T_i$ must also read $O$ from $T_j$ in $S'$.
+ For each $O$, the Tx which performs the final write on $O$ in $S$ must also perform the final write on $O$ in $S'$.

=== View serializability graph (VSG)
A schedule $S$ is a VSS if and only if $"VSG"(S)$ is acyclic.
The serial schedule $S'$ can be produced by a topological sort of the VSG.

The edges of a VSG are derived by the following rules:

- If $T_j$ reads from $T_i$, then $T_i arrow T_j in "VSG"(S)$.
- If both $T_j$ and $T_i$ update the same object $O$ and $T_j$ performs the final write on $O$, then $T_i arrow T_j in "VSG"(S)$.
- If $T_j$ reads some object $O$ from $T_i$, and $T_k$ updates $O$,
  then either $T_k arrow T_i in "VSG"(S)$ or $T_j arrow T_k in "VSG"(S)$.

=== Conflict serializable schedules (CSS)
Two actions on the same object _conflict_ if at least one of them is a write action,
and the actions are from different transactions.

/ Dirty read: $read(1, x), underline(write(1, x)), underline(read(2, x)), write(2, x), abort(1)$
/ Unrepeatable read: $underline(read(1, x)), read(2, x), underline(write(2, x)), commit(2), read(1, x)$
/ Lost update: $read(1, x), read(2, x), underline(write(1, x)), underline(write(2, x))$

A schedule $S$ is a CSS if $S$ is conflict equivalent to some serial schedule $S'$,
if they order every pair of conflicting actions in the same way.

=== Conflict serialiablity graph (CSG)
A schedule $S$ is a CSS if and only if its $"CSG"(S)$ is acyclic.

For each action in $T_i$ which precedes and conflicts with one of $T_j$'s actions, $T_i arrow T_j in "VSG"(S)$.

#theorem()[A schedule that is conflict serializable is also view serializable.]

A write on an object $O$ by $T_i$ is a blind write if $T_i$ did not read $O$ prior to the write.

#theorem()[If $S$ is view serializable and $S$ has no blind writes, then $S$ is also conflict serializable.]

=== Recoverable schedules
If $T_j$ has read from $T_i$, then $T_j$ must abort if $T_i$ aborts, for correctness.
This recursive aborting process is known as cascading aborts.

A schedule $S$ is recoverable if every transaction $T$ that commits in $S$,
$T$ commits after $T'$ if $T$ reads from $T'$.

Recoverable schedules guarantee that committed transactions will not be aborted.

=== Cascadeless schedules
A schedule $S$ is cascadeless if, whenever $T_j$ that reads from $T_i$ in $S$,
$commit(j)$ precedes the read action.

Cascadeless schedules prevent cascading aborts by disallowing dirty reads. Avoiding cascading aborts eliminates their performance penalty and bookkeeping overhead.

#theorem()[A schedule that is cascadeless is also a recoverable schedule.]

=== Strict schedules
Aborted transactions can be efficiently undone with the use of _before-images_ for write actions,
but only for strict schedules.

A schedule is strict if for every $write(i, O)$, $O$ is not read or written by another transaction until $T_i$ aborts or commits.

#theorem()[A strict schedule is also cascadeless.]

== Lock-based concurrency control
Each transaction must request and hold a [shared S | exclusive X] lock on an object before [reading | writing to] the object.

Only either multiple shared locks or a single exclusive lock can be held on an object at a time, but not both.

Requests for locks are queued, and transactions are blocked when the above condition is not met. Locks are released when a transaction commits or aborts.

=== Two phase locking (2PL)
2PL consists of _growing_ and _shrinking_ phases as a consequence of the rule that when a Tx releases a lock, it cannot request for any more locks.

#theorem()[2PL schedules are conflict serializable.]

==== Strict 2PL
Txs must hold on to locks until they commit or abort.

#theorem()[Strict 2PL schedules are strict and conflict serializable.]

S locks can be upgraded as long as the 2PL conditions are upheld.\
X locks can be downgraded, with the additional condition that the object has not been modified.

=== Deadlock detection
A _waits-for graph_ (WFG) consists of edges $T_j arrow T_i$ if $T_j$ waits for $T_i$ to release a lock.
Break deadlocks by aborting a Tx in a cycle.

=== Deadlock prevention
Transactions are assigned timestamps $t$ which persist even if they are aborted (to avoid starvation).
When $T_i$ requests for a lock that conflicts with that held by $T_j$, actions differ by policy:

/ Wait-die: If $t_i$ < $t_j$, $T_i$ waits, else $T_i$ aborts. Non-preemptive.
/ Wound-wait: If $t_i$ < $t_j$, $T_j$ aborts, else $T_i$ waits for $T_j$. Preemptive.

=== ANSI SQL isolation levels
Phantom reads occur when a Tx reads a _table_ with some predicate $p$, but a concurrent Tx committed an `UPDATE`, `INSERT` or `DELETE` operation, such that the set of rows satisfying $p$ changes on a subsequent read with the same predicate $p$.

Note: This is different from unrepeatable reads which are row-level anomalies caused by committed `UPDATE` operations on the _same record_ between reads.

There are four isolation levels, with compounding guarantees:

+ `READ UNCOMMITTED`: prevents lost updates (WW)
+ `READ COMMITTED`: prevents dirty reads (WR)
+ `REPEATABLE READ`: prevents unrepeatable reads (RW)
+ `SERIALIZABLE`: prevents phantom reads

Two lock durations exist:

/ Long duration locks: Locks are held until Tx commits/aborts.
/ Short duration locks: Locks may be released after an operation.

All isolation levels use long duration write locks, but read-locks differ by isolation level:

- `READ UNCOMMITTED`: no read locks
- `READ COMMITTED`: short duration read lock
- `REPEATABLE READ` and `SERIALIZABLE`: long duration read lock

Phantom reads are prevented at the `SERIALIZABLE` level by predicate locking or index locking.

=== Multigranularity locking
Locks can be applied on the entire database, relations, pages, or tuples
which are acquired top-down and released bottom-up.

Intention locks (I locks) are introduced to detect locking conflicts.

#table(
  columns: 5,
  [req. \\ held], [-], [I], [S], [X],
  [I], [$checkmark$], [$checkmark$], [$times$], [$times$],
  [S], [$checkmark$], [$times$], [$checkmark$], [$times$],
  [X], [$checkmark$], [$times$], [$times$], [$times$],
)

To increase concurrency, intention shared (IS) and intention exclusive (IX) locks are added.

To obtain S or IS lock on a node, must already hold IS or IX lock on its parent node.

To obtain X or IX lock on a node, must already hold IX lock on its parent node.

#table(
  columns: 6,
  [req. \\ held], [-], [IS], [IX], [S], [X],
  [IS], [$checkmark$], [$checkmark$], [$checkmark$], [$checkmark$], [$times$],
  [IX], [$checkmark$], [$checkmark$], [$checkmark$], [$times$], [$times$],
  [S], [$checkmark$], [$checkmark$], [$times$], [$checkmark$], [$times$],
  [X], [$checkmark$], [$times$], [$times$], [$times$], [$times$],
)

== Multiversion concurrency control
Write operations create new versions of an object.

This yields several advantages:

- Read-only Txs are not blocked by update Txs.
- Update Txs are not blocked by read-only Txs.
- Read-only Txs are never aborted.

=== Multiversion view serializability (MVSS)

A schedule $S$ is _monoversion_ if all reads in $S$ return the most recently created object version.

A schedule $S$ is an MVSS if $S$ is there exists a serial monoversion schedule $S'$ that is multiversion view equivalent to $S$, requiring $S$ and $S'$ to have the same set of read-from relations, i.e.
if $read(i, x_j)$ occurs in $S$, $read(i, x_j)$ must also occur in $S'$.

#theorem()[If a schedule is view serializable, it is also multiversion view serializable (but the converse is not true).]

=== Snapshot isolation (SI)
Snapshot isolation maintains the concurrent update property that if multiple
concurrent transaction update the same object, only one transaction is allowed to commit.

This property is enforced by either of two rules:

/ First committer wins: Before $T$ commits, if there exists a concurrent $T'$ that updated the same object, $T$ aborts.
/ First updater wins: Txs race to acquire an X lock on $O$. The first to acquire the lock is allowed to commit, and the rest are blocked and subsequently aborted unless the first Tx aborts.

Snapshot isolation guarantees that lost updates, unrepeatable reads, and dirty reads will not occur,
but does not guarantee serializability because of write skew and read-only anomalies.

==== Write skews
When two concurrent Txs race to update _different objects_ dependent on
data read from a snapshot which overlaps that which the other is writing.

Note that this is not a lost update anomaly since the Txs are not updating the same object.

==== Read-only anomaly
When $T_k$ reads from a snapshot at a point in time after $T_i$ commits but before $T_j$ commits,
such that its result could not correspond to a final state after both $T_i$ and $T_j$ commit.

=== Serializable snapshot isolation (SSI)
Guaranteeing that SI produces serializable schedules requires a dependency serialization graph (DSG).

DSGs consist of four possible edge types:

+ $T_i arrow^("ww") T_j$ when $T_i$ writes a version of $O$ and $T_j$ writes its immediate successor.
+ $T_i arrow^("wr") T_j$ when $T_i$ writes a version of $O$ and $T_j$ reads it.
+ $T_i arrow^("rw") T_j$ when $T_i$ and $T_j$ are non-concurrent, and $T_i$ reads a version of $O$ and $T_j$ creates its immediate successor.
+ $T_i arrow.dashed^("rw") T_j$ when $T_i$ and $T_j$ are concurrent, and $T_i$ reads a version of $O$ and $T_j$ creates its immediate successor.

If $T_i arrow.dashed^("rw") T_j arrow.dashed^("rw") T_k$ is detected, one of the transactions is aborted.
Note that $T_i$ and $T_k$ need not be distinct transactions.

This may lead to false positives where the schedule is MVSS but still contains such a pattern.

== Crash recovery
The recovery manager guarantees atomicity and durability.
The way the buffer manager handles dirty pages in the buffer pool depends on the policy in use:

/ Steal policy: Dirty pages updated by a Tx _can_ be written to disk _before_ the Tx commits. Enables undo.
/ Force policy: Dirty pages updated by a Tx _must_ be written to disk when the Tx commits. Disables redo.

Actions executed by te database are logged, and each record is identified by a unique log sequence number (LSN).

=== ARIES recovery algorithm
Steal, no-force approach, using strict 2PL.
Maintains 3 data structures:

+ Log file
+ Transaction table
  - `XactID`: Tx identifier
  - `lastLSN`: LSN of the most recent log record for this Tx
  - `status`: `C` if Tx has committed, `U` otherwise
+ Dirty page table, one entry per dirty page in the buffer pool
  - `pageID`: page ID of the dirty page
  - `recLSN`: LSN of the earliest log record for an update dirtying the page

==== Write-ahead logging
Uncommitted updates must not be flushed to disk until its log record with its before-image has been flushed to the log.

==== Force-at-commit
Transactions must not be committed until the after-images of all its updated records are flushed to the log.

==== Analysis phase
Reconstructs the transaction table with all active transactions with status `U` and without an end log record.

Restores the dirty page table for all pages dirty at the time of the crash.

==== Redo phase
Restores the database state to that of the time of the crash
by replaying updates starting from the earliest `recLSN` in the dirty page table, updating `recLSN` to `pageLSN`.

Then, creates end log records for all transactions with status `C` and removes them from the transaction table.

==== Undo phase
Aborts active transactions at the time of the crash, undoing their actions in reverse order, picking the Tx with the largest `lastLSN` in each iteration.

Creates compensation log records (CLRs) for update log records with `CLR.undoNextLSN := prevLSN`.

Creates end log records when a Tx has no backward links (i.e. `prevLSN` or `undoNextLSN`).

==== Simple checkpointing
Writes a checkpoint log record (CPLR) containing the transaction table, which is then restored during the analysis phase. Inefficient, blocks all transactions while the CPLR is written.

==== Fuzzy checkpointing
Wrties the log records `begin_checkpoint` (BCPLR) and `end_checkpoint` (ECPLR), with the ECPLR containing the transaction and dirty page tables at the time that BCPLR was written.

During the redo phase, if a page is not in the DPT or its `recLSN` in the DPT is greater than the record's LSN, the page itself need not be fetched.
