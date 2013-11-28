{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE TupleSections #-}

module Unparser where

import HypeScript

import Control.Applicative ((<$>), (<|>))
import Control.Monad ((>=>))
import qualified Data.Aeson as Ae
import qualified Data.HashMap.Strict as H
import qualified Data.Vector as V

unparseValue :: Grammar Val t1 t2 -> t2 -> Maybe t1
unparseValue = \case
  -- Any context
  Id -> return
  g1 :. g2 -> unparseValue g1 >=> unparseValue g2
  Empty -> fail "empty grammar"
  g1 :<> g2 -> \x -> unparseValue g1 x <|> unparseValue g2 x
  Pure _ f -> f

  -- Value context
  Literal val -> return . (val :-)
  Object g -> \x -> do
    (obj, y) <- unparseProperties g (H.empty, x)
    return (Ae.Object obj :- y)
  Array g -> \x -> do
    (arr, y) <- unparseElements g (V.empty, x)
    return (Ae.Array arr :- y)

unparseProperties :: Grammar Obj t1 t2 -> (Ae.Object, t2) -> Maybe (Ae.Object, t1)
unparseProperties = \case
  Id -> return
  g1 :. g2 -> unparseProperties g1 >=> unparseProperties g2
  Empty -> fail "empty grammar"
  g1 :<> g2 -> \objx -> unparseProperties g1 objx <|> unparseProperties g2 objx
  Pure _ f -> \(obj, x) -> (obj, ) <$> f x
  Property n gProp -> \(obj, x) -> do
    val :- y <- unparseValue gProp x
    return (H.insert n val obj, y)

unparseElements :: Grammar Arr t1 t2 -> (Ae.Array, t2) -> Maybe (Ae.Array, t1)
unparseElements = \case
  Id -> return
  g1 :. g2 -> unparseElements g1 >=> unparseElements g2
  Empty -> fail "empty grammar"
  g1 :<> g2 -> \x -> unparseElements g1 x <|> unparseElements g2 x
  Pure _ f -> \(arr, x) -> (arr, ) <$> f x
  Element gEl -> \(arr, x) -> do
    val :- y <- unparseValue gEl x
    return (V.cons val arr, y)
