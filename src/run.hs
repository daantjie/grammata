{-# LANGUAGE OverloadedStrings #-}
-- import Debug.Trace
import Control.Monad
import Language.Haskell.Interpreter -- hint
import Data.String
import Data.Monoid
import Grammata.Types
import qualified Data.Text.IO as T
import qualified Data.Text as T
import Data.Text (Text)
import Data.List (isPrefixOf)
import System.Environment
import System.IO (stderr)
import Text.Parsec
import qualified Data.ByteString.Lazy as BL

main :: IO ()
main = do
  args <- getArgs
  progname <- getProgName
  let verbosity = if "-v2" `elem` args
                     then 2
                     else if "-v1" `elem` args
                          then 1
                          else 0
  let args' = filter (not . isPrefixOf "-v") args
  let (format,file) =
         case args' of
              [x,y] -> (x,y)
              _ -> error $ "Usage:  " ++ progname ++
                             "[-v1|-v2] [TeX|Html|PDF] file"

  doc <- readFile file
  r <- runInterpreter (interpretDoc verbosity doc format)

  case r of
       Left (WontCompile es) -> mapM_ (putStrLn . showCompileError file) es
       Left err -> putStrLn (show err)
       Right x  -> do
         render x >>= liftIO . BL.putStr
         liftIO $ BL.putStr "\n"

showCompileError :: [Char] -> GhcError -> [Char]
showCompileError file e =
  if "<interactive>" `isPrefixOf` e'
     then file ++ drop 13 e'
     else e'
  where e' = errMsg e

interpretDoc :: Int -> String -> String -> Interpreter (Doc IO Block)
interpretDoc verbosity doc format = do
  loadModules ["Grammata.Format." ++ format, "Grammata.TH"]
  set [languageExtensions := [TemplateHaskell, OverloadedStrings]]
  setImports ["Prelude", "Grammata.Format." ++ format, "Grammata.TH", "Data.String", "Data.Monoid", "Language.Haskell.TH", "Grammata.Types", "Control.Monad.RWS"]
  x <- typeOf "emph"
  liftIO $ print x
  res <- parseDoc doc
  case res of
       Left e  -> error (show e)
       Right r -> do
          when (verbosity >= 2) $ liftIO $ T.hPutStrLn stderr r
          interpret (T.unpack r) (as :: Doc IO Block)

lookupCommand :: String -> Interpreter (Maybe (String, [String]))
lookupCommand cmd = do
  xs <- interpret ("$(toTypeSpec " ++ show cmd ++ ")") (as :: [String])
  return $
    if null xs
       then Nothing
       else Just (last xs, init xs) -- result, args

type Parser = ParsecT [Char] () Interpreter

pControlSeq :: Parser String
pControlSeq = try $ do
  char '\\'
  cmd <- many1 alphaNum
  spaces
  return cmd

pInlineCommand :: Parser Text
pInlineCommand = do
  cmd <- pControlSeq
  typespec <- lift $ lookupCommand cmd
  case typespec of
       Nothing               -> fail $ "Undefined command " ++ cmd
       Just ("Inline", args) -> ((T.pack cmd <> " ") <>) <$> processArgs args
       Just _                -> fail $ cmd ++ " does not return Inline"

pBlockCommand :: Parser Text
pBlockCommand = do
  cmd <- pControlSeq
  typespec <- lift $ lookupCommand cmd
  case typespec of
       Nothing              -> fail $ "Undefined command " ++ cmd
       Just ("Block", args) -> ((T.pack cmd <> " ") <>) <$> processArgs args
       Just _               -> fail $ cmd ++ " does not return Block"

processArgs :: [String] -> Parser Text
processArgs = fmap mconcat . mapM processArg

processArg :: String -> Parser Text
processArg "Inline" = pInlineArg
processArg "Block" = pBlockArg
processArg x = fail $ "Argument type "  ++ x ++ " unimplemented"

pBraced :: Parser Text -> Parser Text
pBraced p = try $ do
  spaces
  char '{'
  inconcat <$> manyTill p (char '}')

inconcat :: [Text] -> Text
inconcat ts = "(" <> T.intercalate "\n<>\n" ts <> ")"

pComment :: Parser ()
pComment = do
  char '%'
  skipMany (noneOf "\n")
  optional (char '\n')

pSkip :: Parser ()
pSkip = space >> spaces

pText :: Parser Text
pText = (fromString . show) <$> many1 (noneOf "\\{}%")

pInlineArg :: Parser Text
pInlineArg = pBraced (try $ skipMany pComment >> (pText <|> pInlineCommand)
                             <* skipMany pComment)

pBlockArg :: Parser Text
pBlockArg = pBraced (try $ skipMany (pComment <|> pSkip) >> pBlockCommand
                             <* skipMany (pComment <|> pSkip))

parseDoc :: String -> Interpreter (Either ParseError Text)
parseDoc = runParserT
  (T.intercalate "\n<>\n" <$>
    many (try $ skipMany (pComment <|> pSkip) >> pBlockCommand)
      <* spaces <* eof) () "input"

