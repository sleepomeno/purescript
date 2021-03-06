-----------------------------------------------------------------------------
--
-- Module      :  Language.PureScript.Sugar
-- Copyright   :  (c) Phil Freeman 2013
-- License     :  MIT
--
-- Maintainer  :  Phil Freeman <paf31@cantab.net>
-- Stability   :  experimental
-- Portability :
--
-- |
-- Desugaring passes
--
-----------------------------------------------------------------------------

{-# LANGUAGE FlexibleContexts #-}

module Language.PureScript.Sugar (desugar, module S) where

import Control.Monad
import Control.Category ((>>>))
import Control.Applicative
import Control.Monad.Error.Class (MonadError(..))
import Control.Monad.Supply.Class

import Language.PureScript.AST
import Language.PureScript.Errors

import Language.PureScript.Sugar.BindingGroups as S
import Language.PureScript.Sugar.CaseDeclarations as S
import Language.PureScript.Sugar.DoNotation as S
import Language.PureScript.Sugar.Names as S
import Language.PureScript.Sugar.ObjectWildcards as S
import Language.PureScript.Sugar.Operators as S
import Language.PureScript.Sugar.TypeClasses as S
import Language.PureScript.Sugar.TypeDeclarations as S

-- |
-- The desugaring pipeline proceeds as follows:
--
--  * Remove signed literals in favour of `negate` applications
--
--  * Desugar object literals with wildcards into lambdas
--
--  * Desugar operator sections
--
--  * Desugar do-notation using the @Prelude.Monad@ type class
--
--  * Desugar top-level case declarations into explicit case expressions
--
--  * Desugar type declarations into value declarations with explicit type annotations
--
--  * Qualify any unqualified names and types
--
--  * Rebracket user-defined binary operators
--
--  * Introduce type synonyms for type class dictionaries
--
--  * Group mutually recursive value and data declarations into binding groups.
--
desugar :: (Applicative m, MonadSupply m, MonadError MultipleErrors m) => [Module] -> m [Module]
desugar = map removeSignedLiterals
          >>> mapM desugarObjectConstructors
          >=> mapM desugarOperatorSections
          >=> mapM desugarDoModule
          >=> desugarCasesModule
          >=> desugarTypeDeclarationsModule
          >=> desugarImports
          >=> rebracket
          >=> desugarTypeClasses
          >=> createBindingGroupsModule
