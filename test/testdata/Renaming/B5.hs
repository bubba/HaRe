module Renaming.B5 (myFringe)where

import Renaming.D5 hiding (sumSquares)

import qualified Renaming.D5 

instance SameOrNot Float where
   isSame a  b = a ==b
   isNotSame a b = a /=b

myFringe:: Tree a -> [a]
myFringe (Leaf x ) = [x]
myFringe (Branch left right) = myFringe right

sumSquares (x:xs)= x^2 + sumSquares xs
sumSquares [] =0 


  

