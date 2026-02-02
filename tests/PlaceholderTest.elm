module PlaceholderTest exposing (all)

import Expect
import Test exposing (..)


all : Test
all =
    describe "Placeholder"
        [ test "placeholder" <| \_ -> Expect.equal True True
        ]
