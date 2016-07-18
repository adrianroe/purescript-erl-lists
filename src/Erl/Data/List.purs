module Erl.Data.List where

import Prelude

import Control.Alt (class Alt, (<|>))
import Control.Alternative (class Alternative)
import Control.Lazy (class Lazy, defer)
import Control.MonadPlus (class MonadPlus)
import Control.MonadZero (class MonadZero)
import Control.Plus (class Plus)
import Data.Foldable (class Foldable, foldl, foldr, any, intercalate, foldMapDefaultL, foldMapDefaultR)
import Data.Maybe (Maybe(..))
import Data.Monoid (class Monoid, mempty)
import Data.Traversable (class Traversable, traverse, sequence)
import Data.Tuple (Tuple(..))
import Data.Unfoldable (class Unfoldable, unfoldr)

foreign import data List :: * -> *

foreign import nil :: forall a. List a

foreign import cons :: forall a. a -> List a -> List a

infixr 6 cons as :


-- | Convert a list into any unfoldable structure.
-- |
-- | Running time: `O(n)`
toUnfoldable :: forall f a. Unfoldable f => List a -> f a
toUnfoldable = unfoldr (\xs -> (\rec -> Tuple rec.head rec.tail) <$> uncons xs)

-- | Construct a list from a foldable structure.
-- |
-- | Running time: `O(n)`
fromFoldable :: forall f a. Foldable f => f a -> List a
fromFoldable = foldr cons nil

--------------------------------------------------------------------------------
-- List creation ---------------------------------------------------------------
--------------------------------------------------------------------------------

-- | Create a list with a single element.
-- |
-- | Running time: `O(1)`
singleton :: forall a. a -> List a
singleton a = a : nil

-- | An infix synonym for `range`.
infix 8 range as ..

foreign import rangeImpl :: Int -> Int -> Int -> List Int

-- | Create a list containing a range of integers, including both endpoints.
range :: Int -> Int -> List Int
range n m = rangeImpl n m (if n > m then -1 else 1)


-- -- | Attempt a computation multiple times, requiring at least one success.
-- -- |
-- -- | The `Lazy` constraint is used to generate the result lazily, to ensure
-- -- | termination.
-- some :: forall f a. (Alternative f, Lazy (f (List a))) => f a -> f (List a)
-- some v = Cons <$> v <*> defer (\_ -> many v)
--
-- -- | Attempt a computation multiple times, returning as many successful results
-- -- | as possible (possibly zero).
-- -- |
-- -- | The `Lazy` constraint is used to generate the result lazily, to ensure
-- -- | termination.
-- many :: forall f a. (Alternative f, Lazy (f (List a))) => f a -> f (List a)
-- many v = some v <|> pure Nil
--
--------------------------------------------------------------------------------
-- List size -------------------------------------------------------------------
--------------------------------------------------------------------------------

-- | Test whether a list is empty.
-- |
-- | Running time: `O(1)`
foreign import null :: forall a. List a -> Boolean

-- | Get the length of a list
-- |
-- | Running time: `O(n)`
foreign import length :: forall a. List a -> Int

-- --------------------------------------------------------------------------------
-- -- Extending lists -------------------------------------------------------------
-- --------------------------------------------------------------------------------
----
-- -- | Append an element to the end of a list, creating a new list.
-- -- |
-- -- | Running time: `O(2n)`
-- snoc :: forall a. List a -> a -> List a
-- snoc xs x = reverse (Cons x (reverse xs))
--
-- -- | Insert an element into a sorted list.
-- -- |
-- -- | Running time: `O(n)`
-- insert :: forall a. Ord a => a -> List a -> List a
-- insert = insertBy compare
--
-- -- | Insert an element into a sorted list, using the specified function to
-- -- | determine the ordering of elements.
-- -- |
-- -- | Running time: `O(n)`
-- insertBy :: forall a. (a -> a -> Ordering) -> a -> List a -> List a
-- insertBy _ x Nil = Cons x Nil
-- insertBy cmp x ys@(Cons y ys') =
--   case cmp x y of
--     GT -> Cons y (insertBy cmp x ys')
--     _  -> Cons x ys
--
--------------------------------------------------------------------------------
-- Non-indexed reads -----------------------------------------------------------
--------------------------------------------------------------------------------

-- | Get the first element in a list, or `Nothing` if the list is empty.
-- |
-- | Running time: `O(1)`.
head :: forall a. List a -> Maybe a
head = map _.head <<< uncons

-- | Get the last element in a list, or `Nothing` if the list is empty.
-- |
-- | Running time: `O(n)`.
last :: forall a. List a -> Maybe a
last list = case uncons list of
  Just { head, tail } | null tail -> Just head
  Just { tail } -> last tail
  _ -> Nothing

-- | Get all but the first element of a list, or `Nothing` if the list is empty.
-- |
-- | Running time: `O(1)`
tail :: forall a. List a -> Maybe (List a)
tail = map _.tail <<< uncons

-- | Get all but the last element of a list, or `Nothing` if the list is empty.
-- |
-- | Running time: `O(n)`
init :: forall a. List a -> Maybe (List a)
init lst | null lst = Nothing
init lst = Just $ reverse $ go lst nil
  where
  go lst' acc = case uncons lst' of
    Just { head, tail } | null tail -> acc
    Just { head, tail } -> go tail $ head : acc
    Nothing -> acc

--
-- | Break a list into its first element, and the remaining elements,
-- | or `Nothing` if the list is empty.
-- |
-- | Running time: `O(1)`
uncons :: forall a. List a -> Maybe { head :: a, tail :: List a }
uncons = unconsImpl Just Nothing

foreign import unconsImpl :: forall a b. (b -> Maybe b) -> Maybe b -> List a -> Maybe { head :: a, tail :: List a }

--
-- --------------------------------------------------------------------------------
-- -- Indexed operations ----------------------------------------------------------
-- --------------------------------------------------------------------------------
--
-- -- | Get the element at the specified index, or `Nothing` if the index is out-of-bounds.
-- -- |
-- -- | Running time: `O(n)` where `n` is the required index.
-- index :: forall a. List a -> Int -> Maybe a
-- index Nil _ = Nothing
-- index (Cons a _) 0 = Just a
-- index (Cons _ as) i = index as (i - 1)
--
-- -- | An infix synonym for `index`.
-- infixl 8 index as !!
--
-- -- | Find the index of the first element equal to the specified element.
-- elemIndex :: forall a. Eq a => a -> List a -> Maybe Int
-- elemIndex x = findIndex (_ == x)
--
-- -- | Find the index of the last element equal to the specified element.
-- elemLastIndex :: forall a. Eq a => a -> List a -> Maybe Int
-- elemLastIndex x = findLastIndex (_ == x)
--
-- -- | Find the first index for which a predicate holds.
-- findIndex :: forall a. (a -> Boolean) -> List a -> Maybe Int
-- findIndex fn = go 0
--   where
--   go :: Int -> List a -> Maybe Int
--   go n (Cons x xs) | fn x = Just n
--                    | otherwise = go (n + 1) xs
--   go _ Nil = Nothing
--
-- -- | Find the last index for which a predicate holds.
-- findLastIndex :: forall a. (a -> Boolean) -> List a -> Maybe Int
-- findLastIndex fn xs = ((length xs - 1) - _) <$> findIndex fn (reverse xs)
--
-- -- | Insert an element into a list at the specified index, returning a new
-- -- | list or `Nothing` if the index is out-of-bounds.
-- -- |
-- -- | Running time: `O(n)`
-- insertAt :: forall a. Int -> a -> List a -> Maybe (List a)
-- insertAt 0 x xs = Just (Cons x xs)
-- insertAt n x (Cons y ys) = Cons y <$> insertAt (n - 1) x ys
-- insertAt _ _ _  = Nothing
--
-- -- | Delete an element from a list at the specified index, returning a new
-- -- | list or `Nothing` if the index is out-of-bounds.
-- -- |
-- -- | Running time: `O(n)`
-- deleteAt :: forall a. Int -> List a -> Maybe (List a)
-- deleteAt 0 (Cons y ys) = Just ys
-- deleteAt n (Cons y ys) = Cons y <$> deleteAt (n - 1) ys
-- deleteAt _ _  = Nothing
--
-- -- | Update the element at the specified index, returning a new
-- -- | list or `Nothing` if the index is out-of-bounds.
-- -- |
-- -- | Running time: `O(n)`
-- updateAt :: forall a. Int -> a -> List a -> Maybe (List a)
-- updateAt 0 x (Cons _ xs) = Just (Cons x xs)
-- updateAt n x (Cons x1 xs) = Cons x1 <$> updateAt (n - 1) x xs
-- updateAt _ _ _ = Nothing
--
-- -- | Update the element at the specified index by applying a function to
-- -- | the current value, returning a new list or `Nothing` if the index is
-- -- | out-of-bounds.
-- -- |
-- -- | Running time: `O(n)`
-- modifyAt :: forall a. Int -> (a -> a) -> List a -> Maybe (List a)
-- modifyAt n f = alterAt n (Just <<< f)
--
-- -- | Update or delete the element at the specified index by applying a
-- -- | function to the current value, returning a new list or `Nothing` if the
-- -- | index is out-of-bounds.
-- -- |
-- -- | Running time: `O(n)`
-- alterAt :: forall a. Int -> (a -> Maybe a) -> List a -> Maybe (List a)
-- alterAt 0 f (Cons y ys) = Just $
--   case f y of
--     Nothing -> ys
--     Just y' -> Cons y' ys
-- alterAt n f (Cons y ys) = Cons y <$> alterAt (n - 1) f ys
-- alterAt _ _ _  = Nothing
--
--------------------------------------------------------------------------------
-- Transformations -------------------------------------------------------------
--------------------------------------------------------------------------------

-- | Reverse a list.
-- |
-- | Running time: `O(n)`
foreign import reverse :: forall a. List a -> List a
--
-- | Flatten a list of lists.
-- |
-- | Running time: `O(n)`, where `n` is the total number of elements.
foreign import concat :: forall a. List (List a) -> List a

-- | Apply a function to each element in a list, and flatten the results
-- | into a single, new list.
-- |
-- | Running time: `O(n)`, where `n` is the total number of elements.
concatMap :: forall a b. (a -> List b) -> List a -> List b
concatMap f list =
  case uncons list of
    Nothing -> nil
    Just { head, tail } -> f head <> concatMap f tail

-- | Filter a list, keeping the elements which satisfy a predicate function.
-- |
-- | Running time: `O(n)`
foreign import filter :: forall a. (a -> Boolean) -> List a -> List a
--
-- -- | Filter where the predicate returns a monadic `Boolean`.
-- -- |
-- -- | For example:
-- -- |
-- -- | ```purescript
-- -- | powerSet :: forall a. [a] -> [[a]]
-- -- | powerSet = filterM (const [true, false])
-- -- | ```
-- filterM :: forall a m. Monad m => (a -> m Boolean) -> List a -> m (List a)
-- filterM _ Nil = pure Nil
-- filterM p (Cons x xs) = do
--   b <- p x
--   xs' <- filterM p xs
--   pure if b then Cons x xs' else xs'
--
-- -- | Apply a function to each element in a list, keeping only the results which
-- -- | contain a value.
-- -- |
-- -- | Running time: `O(n)`
-- mapMaybe :: forall a b. (a -> Maybe b) -> List a -> List b
-- mapMaybe f = go Nil
--   where
--   go acc Nil = reverse acc
--   go acc (Cons x xs) =
--     case f x of
--       Nothing -> go acc xs
--       Just y -> go (Cons y acc) xs
--
-- -- | Filter a list of optional values, keeping only the elements which contain
-- -- | a value.
-- catMaybes :: forall a. List (Maybe a) -> List a
-- catMaybes = mapMaybe id
--
--
-- -- | Apply a function to each element and its index in a list starting at 0.
-- mapWithIndex :: forall a b. (a -> Int -> b) -> List a -> List b
-- mapWithIndex f lst = reverse $ go 0 lst Nil
--   where
--   go _ Nil acc = acc
--   go n (Cons x xs) acc = go (n+1) xs $ Cons (f x n) acc
--
-- --------------------------------------------------------------------------------
-- -- Sorting ---------------------------------------------------------------------
-- --------------------------------------------------------------------------------
--
-- -- | Sort the elements of an list in increasing order.
-- sort :: forall a. Ord a => List a -> List a
-- sort xs = sortBy compare xs
--
-- -- | Sort the elements of a list in increasing order, where elements are
-- -- | compared using the specified ordering.
-- sortBy :: forall a. (a -> a -> Ordering) -> List a -> List a
-- sortBy cmp = mergeAll <<< sequences
--   -- implementation lifted from http://hackage.haskell.org/package/base-4.8.0.0/docs/src/Data-OldList.html#sort
--   where
--   sequences :: List a -> List (List a)
--   sequences (Cons a (Cons b xs))
--     | a `cmp` b == GT = descending b (singleton a) xs
--     | otherwise = ascending b (Cons a) xs
--   sequences xs = singleton xs
--
--   descending :: a -> List a -> List a -> List (List a)
--   descending a as (Cons b bs)
--     | a `cmp` b == GT = descending b (Cons a as) bs
--   descending a as bs = Cons (Cons a as) (sequences bs)
--
--   ascending :: a -> (List a -> List a) -> List a -> List (List a)
--   ascending a as (Cons b bs)
--     | a `cmp` b /= GT = ascending b (\ys -> as (Cons a ys)) bs
--   ascending a as bs = (Cons (as $ singleton a) (sequences bs))
--
--   mergeAll :: List (List a) -> List a
--   mergeAll (Cons x Nil) = x
--   mergeAll xs = mergeAll (mergePairs xs)
--
--   mergePairs :: List (List a) -> List (List a)
--   mergePairs (Cons a (Cons b xs)) = Cons (merge a b) (mergePairs xs)
--   mergePairs xs = xs
--
--   merge :: List a -> List a -> List a
--   merge as@(Cons a as') bs@(Cons b bs')
--     | a `cmp` b == GT = Cons b (merge as bs')
--     | otherwise = Cons a (merge as' bs)
--   merge Nil bs = bs
--   merge as Nil = as
--
-- --------------------------------------------------------------------------------
-- -- Sublists --------------------------------------------------------------------
-- --------------------------------------------------------------------------------
--
-- -- | Extract a sublist by a start and end index.
-- slice :: forall a. Int -> Int -> List a -> List a
-- slice start end xs = take (end - start) (drop start xs)
--
-- -- | Take the specified number of elements from the front of a list.
-- -- |
-- -- | Running time: `O(n)` where `n` is the number of elements to take.
-- take :: forall a. Int -> List a -> List a
-- take = go Nil
--   where
--   go acc 0 _ = reverse acc
--   go acc _ Nil = reverse acc
--   go acc n (Cons x xs) = go (Cons x acc) (n - 1) xs
--
-- -- | Take those elements from the front of a list which match a predicate.
-- -- |
-- -- | Running time (worst case): `O(n)`
-- takeWhile :: forall a. (a -> Boolean) -> List a -> List a
-- takeWhile p = go Nil
--   where
--   go acc (Cons x xs) | p x = go (Cons x acc) xs
--   go acc _ = reverse acc
--
-- -- | Drop the specified number of elements from the front of a list.
-- -- |
-- -- | Running time: `O(n)` where `n` is the number of elements to drop.
-- drop :: forall a. Int -> List a -> List a
-- drop 0 xs = xs
-- drop _ Nil = Nil
-- drop n (Cons x xs) = drop (n - 1) xs
--
-- -- | Drop those elements from the front of a list which match a predicate.
-- -- |
-- -- | Running time (worst case): `O(n)`
-- dropWhile :: forall a. (a -> Boolean) -> List a -> List a
-- dropWhile p = go
--   where
--   go (Cons x xs) | p x = go xs
--   go xs = xs
--
-- -- | Split a list into two parts:
-- -- |
-- -- | 1. the longest initial segment for which all elements satisfy the specified predicate
-- -- | 2. the remaining elements
-- -- |
-- -- | For example,
-- -- |
-- -- | ```purescript
-- -- | span (\n -> n % 2 == 1) (1 : 3 : 2 : 4 : 5 : Nil) == { init: (1 : 3 : Nil), rest: (2 : 4 : 5 : Nil) }
-- -- | ```
-- -- |
-- -- | Running time: `O(n)`
-- span :: forall a. (a -> Boolean) -> List a -> { init :: List a, rest :: List a }
-- span p (Cons x xs') | p x = case span p xs' of
--   { init: ys, rest: zs } -> { init: Cons x ys, rest: zs }
-- span _ xs = { init: Nil, rest: xs }
--
-- -- | Group equal, consecutive elements of a list into lists.
-- -- |
-- -- | For example,
-- -- |
-- -- | ```purescript
-- -- | group (1 : 1 : 2 : 2 : 1 : Nil) == (1 : 1 : Nil) : (2 : 2 : Nil) : (1 : Nil) : Nil
-- -- | ```
-- -- |
-- -- | Running time: `O(n)`
-- group :: forall a. Eq a => List a -> List (List a)
-- group = groupBy (==)
--
-- -- | Sort and then group the elements of a list into lists.
-- -- |
-- -- | ```purescript
-- -- | group' [1,1,2,2,1] == [[1,1,1],[2,2]]
-- -- | ```
-- group' :: forall a. Ord a => List a -> List (List a)
-- group' = group <<< sort
--
-- -- | Group equal, consecutive elements of a list into lists, using the specified
-- -- | equivalence relation to determine equality.
-- -- |
-- -- | Running time: `O(n)`
-- groupBy :: forall a. (a -> a -> Boolean) -> List a -> List (List a)
-- groupBy _ Nil = Nil
-- groupBy eq (Cons x xs) = case span (eq x) xs of
--   { init: ys, rest: zs } -> Cons (Cons x ys) (groupBy eq zs)
--
-- --------------------------------------------------------------------------------
-- -- Set-like operations ---------------------------------------------------------
-- --------------------------------------------------------------------------------
--
-- -- | Remove duplicate elements from a list.
-- -- |
-- -- | Running time: `O(n^2)`
-- nub :: forall a. Eq a => List a -> List a
-- nub = nubBy eq
--
-- -- | Remove duplicate elements from a list, using the specified
-- -- | function to determine equality of elements.
-- -- |
-- -- | Running time: `O(n^2)`
-- nubBy :: forall a. (a -> a -> Boolean) -> List a -> List a
-- nubBy _     Nil = Nil
-- nubBy eq' (Cons x xs) = Cons x (nubBy eq' (filter (\y -> not (eq' x y)) xs))
--
-- -- | Calculate the union of two lists.
-- -- |
-- -- | Running time: `O(n^2)`
-- union :: forall a. Eq a => List a -> List a -> List a
-- union = unionBy (==)
--
-- -- | Calculate the union of two lists, using the specified
-- -- | function to determine equality of elements.
-- -- |
-- -- | Running time: `O(n^2)`
-- unionBy :: forall a. (a -> a -> Boolean) -> List a -> List a -> List a
-- unionBy eq xs ys = xs <> foldl (flip (deleteBy eq)) (nubBy eq ys) xs
--
-- -- | Delete the first occurrence of an element from a list.
-- -- |
-- -- | Running time: `O(n)`
-- delete :: forall a. Eq a => a -> List a -> List a
-- delete = deleteBy (==)
--
-- -- | Delete the first occurrence of an element from a list, using the specified
-- -- | function to determine equality of elements.
-- -- |
-- -- | Running time: `O(n)`
-- deleteBy :: forall a. (a -> a -> Boolean) -> a -> List a -> List a
-- deleteBy _ _ Nil = Nil
-- deleteBy eq' x (Cons y ys) | eq' x y = ys
-- deleteBy eq' x (Cons y ys) = Cons y (deleteBy eq' x ys)
--
-- infix 5 difference as \\
--
-- -- | Delete the first occurrence of each element in the second list from the first list.
-- -- |
-- -- | Running time: `O(n^2)`
-- difference :: forall a. Eq a => List a -> List a -> List a
-- difference = foldl (flip delete)
--
-- -- | Calculate the intersection of two lists.
-- -- |
-- -- | Running time: `O(n^2)`
-- intersect :: forall a. Eq a => List a -> List a -> List a
-- intersect = intersectBy (==)
--
-- -- | Calculate the intersection of two lists, using the specified
-- -- | function to determine equality of elements.
-- -- |
-- -- | Running time: `O(n^2)`
-- intersectBy :: forall a. (a -> a -> Boolean) -> List a -> List a -> List a
-- intersectBy _  Nil _   = Nil
-- intersectBy _  _   Nil = Nil
-- intersectBy eq xs  ys  = filter (\x -> any (eq x) ys) xs
--
-- --------------------------------------------------------------------------------
-- -- Zipping ---------------------------------------------------------------------
-- --------------------------------------------------------------------------------
--
-- -- | Apply a function to pairs of elements at the same positions in two lists,
-- -- | collecting the results in a new list.
-- -- |
-- -- | If one list is longer, elements will be discarded from the longer list.
-- -- |
-- -- | For example
-- -- |
-- -- | ```purescript
-- -- | zipWith (*) (1 : 2 : 3 : Nil) (4 : 5 : 6 : 7 Nil) == 4 : 10 : 18 : Nil
-- -- | ```
-- -- |
-- -- | Running time: `O(min(m, n))`
-- zipWith :: forall a b c. (a -> b -> c) -> List a -> List b -> List c
-- zipWith f xs ys = reverse $ go xs ys Nil
--   where
--   go Nil _ acc = acc
--   go _ Nil acc = acc
--   go (Cons a as) (Cons b bs) acc = go as bs $ Cons (f a b) acc
--
-- -- | A generalization of `zipWith` which accumulates results in some `Applicative`
-- -- | functor.
-- zipWithA :: forall m a b c. Applicative m => (a -> b -> m c) -> List a -> List b -> m (List c)
-- zipWithA f xs ys = sequence (zipWith f xs ys)
--
-- -- | Collect pairs of elements at the same positions in two lists.
-- -- |
-- -- | Running time: `O(min(m, n))`
-- zip :: forall a b. List a -> List b -> List (Tuple a b)
-- zip = zipWith Tuple
--
-- -- | Transforms a list of pairs into a list of first components and a list of
-- -- | second components.
-- unzip :: forall a b. List (Tuple a b) -> Tuple (List a) (List b)
-- unzip = foldr (\(Tuple a b) (Tuple as bs) -> Tuple (Cons a as) (Cons b bs)) (Tuple Nil Nil)
--
-- --------------------------------------------------------------------------------
-- -- Transpose -------------------------------------------------------------------
-- --------------------------------------------------------------------------------
--
-- -- | The 'transpose' function transposes the rows and columns of its argument.
-- -- | For example,
-- -- |
-- -- |     transpose ((1:2:3:Nil) : (4:5:6:Nil) : Nil) ==
-- -- |       ((1:4:Nil) : (2:5:Nil) : (3:6:Nil) : Nil)
-- -- |
-- -- | If some of the rows are shorter than the following rows, their elements are skipped:
-- -- |
-- -- |     transpose ((10:11:Nil) : (20:Nil) : Nil : (30:31:32:Nil) : Nil) ==
-- -- |       ((10:20:30:Nil) : (11:31:Nil) : (32:Nil) : Nil)
-- transpose :: forall a. List (List a) -> List (List a)
-- transpose Nil = Nil
-- transpose (Cons Nil xss) = transpose xss
-- transpose (Cons (Cons x xs) xss) =
--   (x : mapMaybe head xss) : transpose (xs : mapMaybe tail xss)
--
-- --------------------------------------------------------------------------------
-- -- Folding ---------------------------------------------------------------------
-- --------------------------------------------------------------------------------
--
-- -- | Perform a fold using a monadic step function.
-- foldM :: forall m a b. Monad m => (a -> b -> m a) -> a -> List b -> m a
-- foldM _ a Nil = pure a
-- foldM f a (Cons b bs) = f a b >>= \a' -> foldM f a' bs
--
--------------------------------------------------------------------------------
-- Instances -------------------------------------------------------------------
--------------------------------------------------------------------------------

instance showList :: Show a => Show (List a) where
  show xs | null xs = "nil"
  show xs = "(" <> intercalate " : " (show <$> xs) <> " : nil)"

instance eqList :: Eq a => Eq (List a) where
  eq xs ys = go xs ys true
    where
      go _ _ false = false
      go xs' ys' acc =
        case uncons xs', uncons ys' of
          Nothing, Nothing -> acc
          Just { head: x, tail: xs }, Just { head: y, tail: ys} -> go xs ys $ acc && (y == x)
          _, _ -> false
--
-- instance ordList :: Ord a => Ord (List a) where
--   compare xs ys = go xs ys
--     where
--     go Nil Nil = EQ
--     go Nil _ = LT
--     go _ Nil = GT
--     go (Cons x xs) (Cons y ys) =
--       case compare x y of
--         EQ -> go xs ys
--         other -> other
--
instance semigroupList :: Semigroup (List a) where
  append = appendImpl

foreign import appendImpl :: forall a. List a -> List a -> List a

instance monoidList :: Monoid (List a) where
  mempty = nil

instance functorList :: Functor List where
  map = mapImpl

instance foldableList :: Foldable List where
  foldr = foldrImpl
  foldl = foldlImpl
  foldMap = foldMapDefaultR

foreign import mapImpl :: forall a b. (a -> b) -> List a -> List b

foreign import foldrImpl :: forall a b. (a -> b -> b) -> b -> List a -> b

foreign import foldlImpl :: forall a b. (b -> a -> b) -> b -> List a -> b

instance unfoldableList :: Unfoldable List where
  unfoldr f b = go b nil
    where
      go source memo = case f source of
        Nothing -> reverse memo
        Just (Tuple one rest) -> go rest (cons one memo)

instance traversableList :: Traversable List where
  traverse f lst =
    case uncons lst of
      Nothing -> pure nil
      Just { head, tail } -> cons <$> f head <*> traverse f tail
  sequence lst =
    case uncons lst of
      Nothing -> pure nil
      Just { head, tail } -> cons <$> head <*> sequence tail

instance applyList :: Apply List where
  apply list xs =
    case uncons list of
      Nothing -> nil
      Just { head: f, tail: fs } -> (f <$> xs) <> (fs <*> xs)

instance applicativeList :: Applicative List where
  pure a = a : nil

instance bindList :: Bind List where
  bind = flip concatMap

instance monadList :: Monad List

instance altList :: Alt List where
  alt = append

instance plusList :: Plus List where
  empty = nil

instance alternativeList :: Alternative List

instance monadZeroList :: MonadZero List

instance monadPlusList :: MonadPlus List