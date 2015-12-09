{-# LANGUAGE OverloadedStrings #-}

module Grammata.Format.Html (lit, emph, para, heading, cpuTime) where

import Grammata.Types
import Control.Monad.RWS
import System.CPUTime
import Data.ByteString.Builder (Builder, charUtf8, stringUtf8)

lit :: Monad m => String -> Doc m Inline
lit = return . escapeHtml

emph :: Monad m => Doc m Inline -> Doc m Inline
emph = fmap (Inline . inTag "em" . unInline)

para :: Monad m => Doc m Inline -> Doc m Block
para = fmap (Block . inTag "p" . unInline)

heading :: Monad m => HeadingLevel -> Doc m Inline -> Doc m Block
heading lev = fmap (Block . inTag ("h" <> unHeadingLevel lev) . unInline)

cpuTime :: Doc IO Inline
cpuTime = escapeHtml . show <$> liftIO getCPUTime

-- utility functions
inTag :: String -> Builder -> Builder
inTag tag b = charUtf8 '<' <> stringUtf8 tag <> charUtf8 '>' <> b <>
  stringUtf8 "</" <> stringUtf8 tag <> charUtf8 '>'

escapeHtml :: String -> Inline
escapeHtml = Inline . mconcat . map escapeHtmlChar

escapeHtmlChar :: Char -> Builder
escapeHtmlChar '<' = stringUtf8 "&lt;"
escapeHtmlChar '>' = stringUtf8 "&gt;"
escapeHtmlChar '&' = stringUtf8 "&amp;"
escapeHtmlChar '"' = stringUtf8 "&quot;"
escapeHtmlChar c   = charUtf8 c
