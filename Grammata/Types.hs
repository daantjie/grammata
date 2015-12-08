{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Grammata.Types where

import Data.Text (Text)
import qualified Data.Text as T
import Data.String
import Data.Map as M
import Data.Data
import Control.Monad.RWS

newtype Block = Block Text
  deriving (Read, Show, Eq, Ord, Data, Typeable)

newtype Inline = Inline Text
  deriving (Read, Show, Eq, Ord, Monoid, Data, Typeable)

class Renderable a where
  toText :: a -> Text

instance Renderable Inline where
  toText (Inline t) = t

instance Renderable Block where
  toText (Block t) = t

data DocState = DocState {
    vars :: M.Map Text Text
} deriving (Read, Show, Eq, Ord, Data, Typeable)

type Doc = RWS DocState () DocState

runDoc :: Doc a -> (a, DocState)
runDoc doc =
  let (_, s, _)   = runRWS doc (DocState mempty) (DocState mempty)
      (res, s', _) = runRWS doc (DocState mempty) s
  in  (res, s')

instance IsString (Doc Inline) where
  fromString = return . Inline . fromString

render :: Renderable a => Doc a -> Text
render = toText . fst . runDoc

instance Show a => Show (Doc a) where
  show x = "<" ++ show res ++ ", " ++ show s ++ ">"
      where (res, s) = runDoc x

instance Monoid a => Monoid (Doc a) where
  mempty = return mempty
  mappend d1 d2 = do
    d1v <- d1
    d1s <- get
    put d1s
    d2v <- d2
    return $ d1v <> d2v

instance Monoid Block where
  mempty = mempty
  mappend (Block x) (Block y) =
    let endsInNewline = T.null x || T.last x == '\n'
    in  Block (x <> if endsInNewline then y else ("\n" <> y))

newtype HeadingLevel = HeadingLevel { unHeadingLevel :: String }

instance IsString HeadingLevel where
  fromString = HeadingLevel

