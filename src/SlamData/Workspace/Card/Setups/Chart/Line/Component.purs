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

module SlamData.Workspace.Card.Setups.Chart.Line.Component
  ( lineBuilderComponent
  ) where

import SlamData.Prelude

import Data.Lens ((^?), _Just)

import Global (readFloat, isNaN)

import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.HTML.Properties.ARIA as ARIA

import SlamData.Render.ClassName as CN
import SlamData.Render.Common (row)
import SlamData.Workspace.Card.CardType as CT
import SlamData.Workspace.Card.CardType.ChartType as CHT
import SlamData.Workspace.Card.Component as CC
import SlamData.Workspace.Card.Eval.State as ES
import SlamData.Workspace.Card.Model as M
import SlamData.Workspace.Card.Setups.CSS as CSS
import SlamData.Workspace.Card.Setups.Chart.Line.Component.ChildSlot as CS
import SlamData.Workspace.Card.Setups.Chart.Line.Component.Query as Q
import SlamData.Workspace.Card.Setups.Chart.Line.Component.State as ST
import SlamData.Workspace.Card.Setups.Dimension as D
import SlamData.Workspace.Card.Setups.DimensionMap.Component as DM
import SlamData.Workspace.Card.Setups.DimensionMap.Component.Query as DQ
import SlamData.Workspace.Card.Setups.DimensionMap.Component.State as DS
import SlamData.Workspace.Card.Setups.Package.DSL as P
import SlamData.Workspace.Card.Setups.Package.Lenses as PL
import SlamData.Workspace.Card.Setups.Package.Projection as PP
import SlamData.Workspace.LevelOfDetails (LevelOfDetails(..))

type DSL = CC.InnerCardParentDSL ST.State Q.Query CS.ChildQuery CS.ChildSlot
type HTML = CC.InnerCardParentHTML Q.Query CS.ChildQuery CS.ChildSlot

package ∷ DS.Package
package = P.onPrism (M._BuildLine ∘ _Just) $ DS.interpret do
  dimension ←
    P.field PL._dimension PP._dimension
      >>= P.addSource _.category
      >>= P.addSource _.value
      >>= P.addSource _.time
      >>= P.addSource _.date
      >>= P.addSource _.datetime

  value ←
    P.field PL._value PP._value
      >>= P.addSource _.value
      >>= P.isFilteredBy dimension

  secondValue ←
    P.optional PL._secondValue PP._secondValue
      >>= P.addSource _.value
      >>= P.isFilteredBy value

  size ←
    P.optional PL._size PP._size
      >>= P.addSource _.value
      >>= P.isFilteredBy dimension
      >>= P.isFilteredBy value
      >>= P.isFilteredBy secondValue
      >>= P.isActiveWhen value

  series ←
    P.optional PL._series PP._series
      >>= P.addSource _.category
      >>= P.addSource _.time
      >>= P.isFilteredBy dimension
      >>= P.isActiveWhen dimension

  pure unit



lineBuilderComponent ∷ CC.CardOptions → CC.CardComponent
lineBuilderComponent =
  CC.makeCardComponent (CT.ChartOptions CHT.Line) $ H.parentComponent
    { render
    , eval: cardEval ⨁ setupEval
    , initialState: const ST.initialState
    , receiver: const Nothing
    }

render ∷ ST.State → HTML
render state =
  HH.div
    [ HP.classes [ CSS.chartEditor ]

    ]
    [ HH.slot' CS.cpDims unit (DM.component package) unit
        $ HE.input \l → right ∘ Q.HandleDims l
    , HH.hr_
    , row [ renderOptionalMarkers state ]
    , HH.hr_
    , row [ renderMinSize state, renderMaxSize state ]
    , HH.hr_
    , row [ renderAxisLabelAngle state ]
    ]

renderAxisLabelAngle ∷ ST.State → HTML
renderAxisLabelAngle state =
  HH.div
    [ HP.classes [ CSS.axisLabelParam ]
    ]
    [ HH.label [ HP.classes [ CN.controlLabel ] ] [ HH.text "Label angle" ]
    , HH.input
        [ HP.classes [ CN.formControl ]
        , HP.value $ show $ state.axisLabelAngle
        , ARIA.label "Axis label angle"
        , HE.onValueChange $ HE.input (\s → right ∘ Q.SetAxisLabelAngle s)
        ]
    ]

renderOptionalMarkers ∷ ST.State → HTML
renderOptionalMarkers state =
  HH.div
    [ HP.classes [ CSS.axisLabelParam ]
    ]
    [ HH.label
        [ HP.classes [ CN.controlLabel ] ]
        [ HH.input
            [ HP.type_ HP.InputCheckbox
            , HP.checked state.optionalMarkers
            , ARIA.label "Show data point markers"
            , HE.onChecked $ HE.input_ $ right ∘ Q.ToggleOptionalMarkers
            ]
        , HH.text "Show markers"
        ]
    , HH.small_
        [ HH.text " (disables size measure)"
        ]
    ]


renderMinSize ∷ ST.State → HTML
renderMinSize state =
  HH.div
    [ HP.classes [ CSS.axisLabelParam ]
    ]
    [ HH.label
        [ HP.classes [ CN.controlLabel ] ]
        [ HH.text if state.optionalMarkers then "Size" else "Minimum size" ]
    , HH.input
        [ HP.classes [ CN.formControl ]
        , HP.value $ show $ state.minSize
        , ARIA.label "Min size"
        , HE.onValueChange $ HE.input (\s → right ∘ Q.SetMinSymbolSize s)
        ]
    ]

renderMaxSize ∷ ST.State → HTML
renderMaxSize state =
  HH.div
    [ HP.classes [ CSS.axisLabelParam ]
    ]
    [ HH.label [ HP.classes [ CN.controlLabel ] ] [ HH.text "Maximum size" ]
    , HH.input
        [ HP.classes [ CN.formControl ]
        , HP.value $ show $ state.maxSize
        , ARIA.label "Max size"
        , HP.disabled state.optionalMarkers
        , HE.onValueChange$ HE.input (\s → right ∘ Q.SetMaxSymbolSize s)
        ]
    ]


cardEval ∷ CC.CardEvalQuery ~> DSL
cardEval = case _ of
  CC.Activate next →
    pure next
  CC.Deactivate next →
    pure next
  CC.Save k → do
    st ← H.get
    let
      inp = M.BuildLine $ Just
        { dimension: D.topDimension
        , value: D.topDimension
        , secondValue: Nothing
        , series: Nothing
        , size: Nothing
        , optionalMarkers: st.optionalMarkers
        , axisLabelAngle: st.axisLabelAngle
        , minSize: st.minSize
        , maxSize: st.maxSize
        }
    out ← H.query' CS.cpDims unit $ H.request $ DQ.Save inp
    pure $ k case join out of
      Nothing → M.BuildLine Nothing
      Just a → a
  CC.Load m next → do
    _ ← H.query' CS.cpDims unit $ H.action $ DQ.Load $ Just m
    for_ (m ^? M._BuildLine ∘ _Just) \r →
      H.modify _{ axisLabelAngle = r.axisLabelAngle
                , optionalMarkers = r.optionalMarkers
                , minSize = r.minSize
                , maxSize = r.maxSize
                }
    pure next
  CC.ReceiveInput _ _ next →
    pure next
  CC.ReceiveOutput _ _ next →
    pure next
  CC.ReceiveState evalState next → do
    for_ (evalState ^? ES._Axes) \axes → do
      H.query' CS.cpDims unit $ H.action $ DQ.SetAxes axes
    pure next
  CC.ReceiveDimensions dims reply → do
    pure $ reply
      if dims.width < 576.0 ∨ dims.height < 416.0
      then Low
      else High

raiseUpdate ∷ DSL Unit
raiseUpdate =
  H.raise CC.modelUpdate

setupEval ∷ Q.Query ~> DSL
setupEval = case _ of
  Q.SetAxisLabelAngle str next → do
    let fl = readFloat str
    unless (isNaN fl) do
      H.modify _{ axisLabelAngle = fl }
      raiseUpdate
    pure next
  Q.SetMinSymbolSize str next → do
    let fl = readFloat str
    unless (isNaN fl) do
      H.modify \st →
        st{ minSize = fl
          , maxSize = if st.maxSize > fl then st.maxSize else fl
          }
      raiseUpdate
    pure next
  Q.SetMaxSymbolSize str next → do
    let fl = readFloat str
    unless (isNaN fl) do
      H.modify \st →
        st{ maxSize = fl
          , minSize = if st.minSize < fl then st.minSize else fl
          }
      raiseUpdate
    pure next
  Q.ToggleOptionalMarkers next → do
    H.modify \st → st{ optionalMarkers = not st.optionalMarkers }
    raiseUpdate
    pure next
  Q.HandleDims q next → do
    case q of
      DQ.Update fld → do
        when ((fld >>= PP.printProjection) ≡ Just "size")
          $ H.modify _{ optionalMarkers = false }
        raiseUpdate
    pure next
