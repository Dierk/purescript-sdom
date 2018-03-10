module Main where

import Prelude

import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Exception (EXCEPTION, throw)
import Control.Monad.Eff.Ref (REF)
import DOM (DOM)
import DOM.HTML (window)
import DOM.HTML.Types (htmlDocumentToNonElementParentNode)
import DOM.HTML.Window (document)
import DOM.Node.NonElementParentNode (getElementById)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Newtype (wrap)
import FRP (FRP)
import FRP.Event (Event, keepLatest)
import FRP.Event.Time (interval)
import SDOM (SDOM, attach, interpretChannel, text)
import SDOM.Attributes as A
import SDOM.Elements as E
import SDOM.Events as Events

data Mode = Increasing | Decreasing | Neither

derive instance eqMode :: Eq Mode

type State =
  { mode :: Mode
  , value :: Int
  }

counter
  :: forall context
   . SDOM Mode context State State
counter =
  E.div_
    [ E.h1_ [ text \_ _ -> "Async" ]
    , E.p_ [ text \_ { value } -> show value ]
    , E.p_
      [ E.button
          [ A.disabled \_ { mode } -> mode == Decreasing ]
          [ Events.click \_ _ -> Left Decreasing ]
          [ text \_ _ -> "Decrement" ]
      , text \_ _ -> " "
      , E.button
          [ A.disabled \_ { mode } -> mode == Neither ]
          [ Events.click \_ _ -> Left Neither ]
          [ text \_ _ -> "Stop" ]
      , text \_ _ -> " "
      , E.button
        [ A.disabled \_ { mode } -> mode == Increasing ]
        [ Events.click \_ _ -> Left Increasing ]
        [ text \_ _ -> "Increment" ]
      ]
    ]

counter_ :: forall channel context. SDOM channel context State State
counter_ =
    interpretChannel interpreter counter
  where
    interpreter :: Event Mode -> Event (Either channel (State -> State))
    interpreter = keepLatest <<< map (map pure <<< fromMode)

    fromMode :: Mode -> Event (State -> State)
    fromMode Increasing = interval 100 $> \{ value } -> { mode: Increasing, value: value + 1 }
    fromMode Decreasing = interval 100 $> \{ value } -> { mode: Decreasing, value: value - 1 }
    fromMode Neither = pure \{ value } -> { mode: Neither, value }

    overValue :: (Int -> Int) -> State -> State
    overValue f o = o { value = f o.value }

main :: Eff ( dom :: DOM
            , exception :: EXCEPTION
            , frp :: FRP
            , ref :: REF
            ) Unit
main = do
  document <- map htmlDocumentToNonElementParentNode (window >>= document)
  container <- getElementById (wrap "container") document
  case container of
    Just el -> void do
      attach el { value: 0, mode: Neither } counter_
    Nothing -> throw "No 'container' node!"
