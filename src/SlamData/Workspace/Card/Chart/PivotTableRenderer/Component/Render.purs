{-
Copyright 2017 SlamData, Inc.

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

module SlamData.Workspace.Card.Chart.PivotTableRenderer.Component.Render where

import SlamData.Prelude

import Data.Argonaut as J
import Data.Array as Array
import Data.Lens ((^.), (^?))
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import SlamData.Render.CSS.New as CSS
import SlamData.Render.Icon as I
import SlamData.Workspace.Card.Chart.PivotTableRenderer.Common (PTree, foldTree, sizeOfRow, topField)
import SlamData.Workspace.Card.Chart.PivotTableRenderer.Component.Query as Q
import SlamData.Workspace.Card.Chart.PivotTableRenderer.Component.State as S
import SlamData.Workspace.Card.Setups.Chart.PivotTable.Model (Column(..))
import SlamData.Workspace.Card.Setups.Chart.PivotTable.Model as PTM
import SlamData.Workspace.Card.Setups.Dimension as D
import SlamData.Workspace.Card.Setups.DisplayOptions.Model as Display
import SlamData.Workspace.Card.Setups.Transform as T
import Utils (showPrettyNumber, showFormattedNumber)

type HTML = H.ComponentHTML Q.Query

render ∷ S.State → HTML
render st =
  case st.port of
    Just port →
      HH.div
        [ HP.classes [ HH.ClassName "sd-pivot-table" ] ]
        [ HH.div
            [ HP.classes [ HH.ClassName "sd-pivot-table-content" ] ]
            [ maybe (HH.text "") (renderTable st.pageCount port.dimensions port.columns) st.buckets ]
        , HH.div
            [ HP.classes
                [ HH.ClassName "sd-pagination"
                , HH.ClassName "sd-form"
                ]
            ]
            [ renderPrevButtons (st.pageIndex > 0)
            , renderPageField st.pageIndex st.customPage st.pageCount
            , renderNextButtons (st.pageIndex < st.pageCount - 1)
            , renderPageSizeControls st.pageSize
            ]
            , if st.loading
                then HH.div [ HP.classes [ HH.ClassName "loading" ] ] []
                else HH.text ""
        ]
    _ → HH.text ""

renderTable
  ∷ Int
  → Array (String × PTM.GroupByDimension)
  → Array (String × PTM.ColumnDimension)
  → PTree J.Json J.Json
  → HTML
renderTable pageCount dims cols tree
  | pageCount == 0 =
      HH.div
        [ HP.classes [ HH.ClassName "no-results" ] ]
        [ HH.text "No results" ]
  | otherwise =
      HH.table_
          $ [ HH.tr_
              $ (dims <#> \(n × dim) → HH.th_ [ HH.text (headingText n dim) ])
              ⊕ (cols <#> \(n × _ × col) → HH.th_ [ HH.text (headingText (columnHeading n col) col) ])
          ]
          ⊕ renderRows cols tree

headingText ∷ ∀ a. String → D.Dimension Void a → String
headingText default = case _ of
  D.Dimension (Just (D.Static str)) _ → str
  _ → default

columnHeading ∷ ∀ a. String → D.Dimension a PTM.Column → String
columnHeading default col = case col ^? D._value ∘ D._projection of
  Just All → "*"
  Just _   → default
  Nothing  → ""

renderRows
  ∷ Array (String × PTM.ColumnDimension)
  → PTree J.Json J.Json
  → Array HTML
renderRows cols =
  map HH.tr_ ∘ foldTree (foldMap (renderLeaf cols)) (foldMap renderHeading)

renderHeading ∷ J.Json × Array (Array HTML) → Array (Array HTML)
renderHeading (k × rs) =
  case Array.uncons rs of
    Just { head, tail } →
      Array.cons
        (Array.cons
          (HH.th [ HP.rowSpan (Array.length rs) ] [ HH.text (renderJson k) ])
          head)
        tail
    Nothing →
      []

renderLeaf
  ∷ Array (String × PTM.ColumnDimension)
  → J.Json
  → Array (Array HTML)
renderLeaf cols row =
  let
    rowLen = sizeOfRow cols row
  in
    Array.range 0 (rowLen - 1) <#> \rowIx →
      cols <#> \(c × opts × col) →
        let text = renderValue opts rowIx (col ^. D._value) <$> J.cursorGet (topField c) row
        in HH.td_ [ HH.text (fromMaybe "" text) ]

renderValue ∷ Display.DisplayOptions → Int → D.Category Column → J.Json → String
renderValue opts = case _, _ of
  0, D.Static _ → renderJson
  0, D.Projection (Just T.Count) _ → J.foldJsonNumber "" showFormattedNumber
  0, D.Projection _ (Column _) → foldJsonArray' renderJson (maybe "" renderJson ∘ flip Array.index 0)
  i, D.Projection _ _ → foldJsonArray' (const "") (maybe "" renderJson ∘ flip Array.index i)
  _, _ → const ""

renderJson ∷ J.Json → String
renderJson =
  J.foldJson show show showPrettyNumber id (show ∘ J.fromArray) (show ∘ J.fromObject)

renderPrevButtons ∷ Boolean → HTML
renderPrevButtons enabled =
  HH.div
    [ HP.class_ CSS.formButtonGroup ]
    [ HH.button
        [ HP.class_ CSS.formButton
        , HP.disabled (not enabled)
        , HE.onClick $ HE.input_ (Q.StepPage Q.First)
        ]
        [ I.playerRewind ]
    , HH.button
        [ HP.class_ CSS.formButton
        , HP.disabled (not enabled)
        , HE.onClick $ HE.input_ (Q.StepPage Q.Prev)
        ]
        [ I.playerPrevious ]
    ]

renderPageField ∷ Int → Maybe String → Int → HTML
renderPageField currentPage customPage totalPages =
  HH.div_
    [ HH.form
        [ HE.onSubmit (HE.input Q.UpdatePage) ]
        [ HH.text "Page"
        , HH.input
            [ HP.type_ HP.InputNumber
            , HP.value (fromMaybe (show (currentPage + 1)) customPage)
            , HE.onValueInput (HE.input Q.SetCustomPage)
            ]
        , HH.text $ "of " <> show totalPages
        ]
    ]

renderNextButtons ∷ Boolean → HTML
renderNextButtons enabled =
  HH.div
    [ HP.class_ CSS.formButtonGroup ]
    [ HH.button
        [ HP.disabled (not enabled)
        , HE.onClick $ HE.input_ (Q.StepPage Q.Next)
        ]
        [ I.playerNext ]
    , HH.button
        [ HP.disabled (not enabled)
        , HE.onClick $ HE.input_ (Q.StepPage Q.Last)
        ]
        [ I.playerFastForward ]
    ]

renderPageSizeControls ∷ Int → HTML
renderPageSizeControls pageSize =
  let
    sizeValues = [10, 25, 50, 100]
    options = sizeValues <#> \value →
      HH.option
        [ HP.selected (value ≡ pageSize) ]
        [ HH.text (show value) ]
  in
    HH.div_
      [ HH.select
          [ HE.onValueChange (HE.input Q.ChangePageSize) ]
          options
      ]

foldJsonArray'
  ∷ ∀ a
  . (J.Json → a)
  → (J.JArray → a)
  → J.Json
  → a
foldJsonArray' f g j = J.foldJson f' f' f' f' g f' j
  where
  f' ∷ ∀ b. b → a
  f' _ = f j
