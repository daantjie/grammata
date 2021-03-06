module Grammata.Util (runxelatex, showInterpreterError) where

import Language.Haskell.Interpreter (InterpreterError(..), errMsg)
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as BL
import System.Directory
import System.Process
import System.Exit
import System.IO
import System.IO.Temp

runxelatex :: BL.ByteString -> IO B.ByteString
runxelatex b = withSystemTempDirectory "grammata.XXXX" $ \dir -> do
    oldDir <- getCurrentDirectory
    setCurrentDirectory dir
    BL.writeFile "temp.tex" b
    ec <- rawSystem "xelatex" ["-interaction=nonstopmode", "temp.tex"]
    case ec of
        ExitFailure code -> do
          hPutStrLn stderr $ "Could not create PDF:"
          readFile "temp.log" >>= hPutStrLn stderr
          exitWith $ ExitFailure 1
        ExitSuccess      -> do
          setCurrentDirectory oldDir
          B.readFile (dir ++ "/temp.pdf")

showInterpreterError :: InterpreterError -> String
showInterpreterError err =
  case err of
       (WontCompile es) -> concatMap errMsg es
       (NotAllowed e) -> e
       (UnknownError e) -> e
       (GhcException e) -> e
