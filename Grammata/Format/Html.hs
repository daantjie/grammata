{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE DeriveDataTypeable #-}

module Grammata.Format.Html (lit, emph, para, heading) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Monoid ((<>))
import Data.Data
import Data.Typeable
import Grammata.Types

lit :: Text -> Doc Inline
lit = return . escapeHtml

emph :: Doc Inline -> Doc Inline
emph = fmap (Inline . inTag "em" . toText)

para :: Doc Inline -> Doc Block
para = fmap (Block . inTag "p" . toText)

heading :: Int -> Doc Inline -> Doc Block
heading lev = fmap (Block . inTag ("h" <> T.pack (show lev)) . toText)

-- utility functions
inTag :: Text -> Text -> Text
inTag tag t = "<" <> tag <> ">" <> t <> "</" <> tag <> ">"

escapeHtml :: Text -> Inline
escapeHtml = Inline . T.concatMap escapeHtmlChar

escapeHtmlChar :: Char -> Text
escapeHtmlChar '<' = "&lt;"
escapeHtmlChar '>' = "&gt;"
escapeHtmlChar '&' = "&amp;"
escapeHtmlChar '"' = "&quot;"
escapeHtmlChar c   = T.singleton c
