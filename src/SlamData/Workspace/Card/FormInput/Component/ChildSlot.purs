{-
Copyright 2016 SlamData, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-}

module SlamData.Workspace.Card.FormInput.Component.ChildSlot where

import SlamData.Prelude

import Halogen.Component.ChildPath (ChildPath, cpR, cpL, (:>))

import SlamData.Workspace.Card.FormInput.TextLikeRenderer.Component as TLR
import SlamData.Workspace.Card.FormInput.LabeledRenderer.Component as LR
import SlamData.Workspace.Card.Chart.MetricRenderer.Component as M

type ChildState =
  TLR.State ⊹ LR.State ⊹ M.State
type ChildQuery =
  TLR.Query ⨁ LR.Query ⨁ M.Query
type ChildSlot =
  Unit ⊹ Unit ⊹ Unit

cpTextLike
  ∷ ChildPath
      TLR.State ChildState
      TLR.Query ChildQuery
      Unit ChildSlot
cpTextLike = cpL

cpLabeled
  ∷ ChildPath
      LR.State ChildState
      LR.Query ChildQuery
      Unit ChildSlot
cpLabeled = cpR :> cpL

cpMetric
  ∷ ChildPath
      M.State ChildState
      M.Query ChildQuery
      Unit ChildSlot
cpMetric = cpR :> cpR
