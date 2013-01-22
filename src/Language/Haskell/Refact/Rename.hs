module Language.Haskell.Refact.Rename(rename,t1) where

import qualified Data.Generics.Schemes as SYB
import qualified Data.Generics.Aliases as SYB
import qualified GHC.SYB.Utils         as SYB

import qualified GHC
import qualified DynFlags              as GHC
import qualified Outputable            as GHC
import qualified MonadUtils            as GHC
import qualified Name                  as GHC
import qualified RdrName               as GHC
import qualified OccName               as GHC
import qualified Unique                as GHC
import qualified FastString            as GHC
import qualified HsPat                 as GHC

import qualified Data.Generics as SYB
import qualified GHC.SYB.Utils as SYB

import GHC.Paths ( libdir )
import Control.Monad
import Control.Monad.State
import Data.Data
import Data.Maybe

import Language.Haskell.Refact.Utils
import Language.Haskell.Refact.Utils.GhcUtils
import Language.Haskell.Refact.Utils.LocUtils
import Language.Haskell.Refact.Utils.Monad
import Language.Haskell.Refact.Utils.TypeSyn
import Language.Haskell.Refact.Utils.TypeUtils

t1 = rename ["../old/refactorer/B.hs","4","7","4","43"]

-- TODO: This boilerplate will be moved to the coordinator, just the refac session will be exposed
rename :: [String] -> IO () -- For now
rename args
  = do let fileName = args!!0
           newName = args!!1
           beginPos = (read (args!!2), read (args!!3))::(Int,Int)
       runRefacSession Nothing (comp fileName newName beginPos)
       return ()

-- body of refac
comp :: String -> String -> SimpPos -> RefactGhc [ApplyRefacResult]
comp fileName newName beginPos = do
       -- modInfo@((_, renamed, ast), toks) <- parseSourceFileGhc fileName
       modInfo@(t, toks) <- parseSourceFileGhc fileName
       let renamed = gfromJust "ifToCase" $ GHC.tm_renamed_source t
       let name = locToName (GHC.mkFastString fileName) beginPos renamed
       let name' = eFromJust name ("There was no variable at " ++ (show beginPos))
       -- let expr = locToExp beginPos endPos renamed
--       case expr of
--         Just exp1@(GHC.L _ (GHC.HsIf _ _ _ _))
       refactoredMod <- applyRefac (rename' name' newName) (Just modInfo ) fileName
       return [refactoredMod]
       --  _      -> error $ "You haven't selected an if-then-else  expression!" --  ++ (show (beginPos,endPos,fileName)) ++ "]:" ++ (SYB.showData SYB.Parser 0 $ ast)

eFromJust :: Maybe a -> String -> a
eFromJust (Just a) _ = a
eFromJust Nothing errorMessage = error errorMessage

rename' (GHC.L _ name) newName = do
  rs <- getRefactRenamed
  reallyRename rs name newName

reallyRename rs name newNameStr = do
   everywhereMStaged SYB.Renamer (SYB.mkM inExp `SYB.extM` inPat `SYB.extM` inFun) rs
   return ()
       where
         inExp :: (GHC.Located (GHC.HsExpr GHC.Name)) -> RefactGhc (GHC.Located (GHC.HsExpr GHC.Name))
         inExp exp1@(GHC.L x (GHC.HsVar n2))
          | GHC.nameUnique name == GHC.nameUnique n2
           = do
               let (free, declared) = hsFreeAndDeclaredPNs rs -- free and declared
                   fd = map nameToString (free ++ declared)
               newName <- mkNewGhcName newNameStr
               let newExp = GHC.L x (GHC.HsVar newName)
               update exp1 newExp exp1
               return newExp

         inExp e = return e
         
         inPat :: (GHC.Located (GHC.Pat GHC.Name)) -> RefactGhc (GHC.Located (GHC.Pat GHC.Name))
         inPat exp1@(GHC.L x (GHC.VarPat n2))
           | GHC.nameUnique name == GHC.nameUnique n2
            = do
                let (free, declared) = hsFreeAndDeclaredPNs rs -- free and declared
                    fd = map nameToString (free ++ declared)
                newName <- mkNewGhcName newNameStr
                let newExp = GHC.L x (GHC.VarPat newName)
                update exp1 newExp exp1
                return newExp

         inPat e = return e
         
         inFun :: (GHC.Located (GHC.HsBindLR GHC.Name GHC.Name)) -> RefactGhc (GHC.Located (GHC.HsBindLR GHC.Name GHC.Name))
         inFun fun1@(GHC.L y (GHC.FunBind (GHC.L x n2) a b c fvs d))
            | GHC.nameUnique name == GHC.nameUnique n2
            = do
                let (free, declared) = hsFreeAndDeclaredPNs rs -- free and declared
                    fd = map nameToString (free ++ declared)
                newName <- mkNewGhcName newNameStr
                let newFun = GHC.L y (GHC.FunBind (GHC.L x newName) a b c fvs d)
                update fun1 newFun fun1
                return newFun

         inFun e = return e
          
          -- bind ((GHC.FunBind _ _ _ _ fvs _)::(GHC.HsBindLR GHC.Name GHC.Name)) = [fvs]
          -- bind ((GHC.PatBind _ _ _ fvs _)  ::(GHC.HsBindLR GHC.Name GHC.Name)) = [fvs]
          -- bind _ = []