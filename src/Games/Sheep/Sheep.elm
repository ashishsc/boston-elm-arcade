module Games.Sheep.Sheep exposing (Sheep, State(..), update, view)

import Collage exposing (Collage)
import Color exposing (Color)
import P2 exposing (P2)
import Radians exposing (Radians)
import V2 exposing (V2)


type alias Sheep =
    { pos : P2
    , vel : V2
    , mass : Float
    , food : Float
    , state : State
    }


type State
    = Flocking
    | Grazing
    | Sleeping


update : Float -> { r | pos : P2 } -> List Sheep -> Sheep -> Sheep
update frames doggo flock sheep =
    case sheep.state of
        Flocking ->
            updateFlocking frames doggo flock sheep

        Grazing ->
            updateGrazing frames doggo flock sheep

        Sleeping ->
            updateSleeping frames doggo flock sheep


updateFlocking : Float -> { r | pos : P2 } -> List Sheep -> Sheep -> Sheep
updateFlocking frames doggo flock sheep =
    let
        -- The flock within the sheep's awareness, paired with the vector to
        -- each sheep, and its norm.
        nearbyFlock : List ( Sheep, V2, Float )
        nearbyFlock =
            List.filterMap
                (\nearbySheep ->
                    let
                        vec =
                            P2.diff nearbySheep.pos sheep.pos

                        norm =
                            V2.norm vec
                    in
                    if norm <= gAwarenessRadius then
                        Just ( nearbySheep, vec, norm )

                    else
                        Nothing
                )
                flock

        -- Average velocity of a sheep in the flock.
        flockVelocity : V2
        flockVelocity =
            nearbyFlock
                |> List.map (\( nearbySheep, _, _ ) -> nearbySheep.vel)
                |> V2.sum
                |> V2.scale (1 / toFloat (List.length flock))

        -- The force the flock has on a sheep. It's a bit tricky, not every
        -- nearby sheep necessarily has a force on the current one.
        --
        -- * A sheep is considered "content" if, of the sheep it is aware of
        --   (in its "awareness radius"), at least two of them is in its
        --   "comfort zone" (even if that sheep is too close for comfort, i.e.
        --   in its "personal space").
        --
        -- * If a sheep is "content", then it feels part of a flock, and is not
        --   explicitly attracted to any nearby sheep. However, it is still
        --   repelled by sheep in its "personal space"
        --
        -- * Otherwise, if a sheep is not "content", then it is attracted to any
        --   sheep it is aware of (since, per the above logic, they all must be
        --   within its "awareness radius" but outside its "personal space").
        --
        -- This logic keeps a flock of sheep from being pulled towards the
        -- center. Sheep on the edge of a flock feel just as a part of it as
        -- sheep in the center.
        flockForce : V2
        flockForce =
            let
                ( veryNearbyFlock, fringeFlock ) =
                    List.partition
                      (\( _, _, norm ) -> norm <= gComfortZoneRadius)
                      nearbyFlock
            in
            if List.length veryNearbyFlock < 2 then
                nearbyFlock
                    |> List.map (sheepForce sheep)
                    |> V2.sum

            else
                veryNearbyFlock
                    |> List.filter (\( _, _, norm ) -> norm <= gPersonalSpaceRadius)
                    |> List.map (sheepForce sheep)
                    |> V2.sum

        doggoForce : V2
        doggoForce =
            let
                diff =
                    P2.diff doggo.pos sheep.pos

                norm =
                    V2.norm diff
            in
            if norm <= gAwarenessRadius then
                V2.scale gDoggoRepelForce (V2.negate (V2.signorm diff))

            else
                V2.zero
    in
    { sheep
        | vel =
            -- New sheep's base velocity is calculated as:
            --
            --   * 60% its previous velocity
            --   * 40% the nearby flock's velocity (hive mind)
            --
            -- Then, the flock's and doggo's forces are applied, and the
            -- velocity is clamped.
            V2.lerp 0.6 sheep.vel flockVelocity
                |> V2.add flockForce
                |> V2.add doggoForce
                |> V2.minNorm gMinVelocity
                |> V2.maxNorm gMaxVelocity
        , pos = P2.add sheep.pos (V2.scale frames sheep.vel)
        , food = sheep.food - (gFoodLossRate * frames)
    }


{-| Calculate the force one sheep has on another:

    * If the sheep are within the "personal space", they repel
    * Otherwise, they attract (constant force)

-}
sheepForce : Sheep -> ( Sheep, V2, Float ) -> V2
sheepForce sheep ( otherSheep, diff, norm ) =
    if norm <= gPersonalSpaceRadius then
        V2.scale gSheepRepelForce (V2.negate (V2.signorm diff))

    else
        V2.scale gSheepAttractForce (V2.signorm diff)


updateGrazing : Float -> { r | pos : P2 } -> List Sheep -> Sheep -> Sheep
updateGrazing frames doggo flock sheep =
    if sheep.food > 1 then
        { sheep | state = Flocking }

    else
        { sheep | food = sheep.food + frames * gFoodGainRate }


updateSleeping : Float -> { r | pos : P2 } -> List Sheep -> Sheep -> Sheep
updateSleeping frames doggo flock sheep =
    sheep



--------------------------------------------------------------------------------
-- View
--------------------------------------------------------------------------------


view : Sheep -> Collage msg
view sheep =
    let
        color =
            case sheep.state of
                Flocking ->
                    Color.rgb 255 0 0

                Grazing ->
                    Color.rgb 0 255 0

                Sleeping ->
                    Color.rgb 0 0 255

        radii c =
            Collage.group
                [ Collage.circle gAwarenessRadius
                    |> Collage.outlined (Collage.dot Collage.thin (Collage.uniform Color.black))
                , Collage.circle gComfortZoneRadius
                    |> Collage.outlined (Collage.dot Collage.thin (Collage.uniform Color.green))
                , Collage.circle gPersonalSpaceRadius
                    |> Collage.outlined (Collage.dot Collage.thin (Collage.uniform Color.red))
                , c
                ]
    in
    Collage.group
        [ Collage.rectangle
            4
            4
            |> Collage.filled (Collage.uniform color)
        , Collage.rectangle
            36
            24
            |> Collage.filled (Collage.uniform (Color.rgb 220 220 220))
        , Collage.rectangle
            8
            8
            |> Collage.filled (Collage.uniform (Color.rgb 20 20 20))
            |> Collage.shift ( 20, 0 )
        ]
        |> Collage.scale sheep.mass
        |> (if False then
                radii

            else
                identity
           )
        |> Collage.rotate (V2.toRadians sheep.vel)
        |> Collage.shift ( P2.x sheep.pos, P2.y sheep.pos )



--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------


{-| Velocity per frame
-}
gMaxVelocity : Float
gMaxVelocity =
    1


gMinVelocity : Float
gMinVelocity =
    0.5


{-| Radians per frame
-}
gTurnRate : Radians
gTurnRate =
    0.01


{-| How far a sheep is aware of its surroundings.
-}
gAwarenessRadius : Float
gAwarenessRadius =
    400


{-| Sheep prefer to be within this many units of other sheep.
-}
gComfortZoneRadius : Float
gComfortZoneRadius =
    300


{-| Sheep inside each others' personal space repel each other.
-}
gPersonalSpaceRadius : Float
gPersonalSpaceRadius =
    40


gMaxFlockForce : Float
gMaxFlockForce =
    0.1


gSheepAttractForce : Float
gSheepAttractForce =
    0.01


gSheepRepelForce : Float
gSheepRepelForce =
    gSheepAttractForce * 5


gDoggoRepelForce : Float
gDoggoRepelForce =
    gSheepRepelForce * 50


gFoodLossRate : Float
gFoodLossRate =
    0.002


gFoodGainRate : Float
gFoodGainRate =
    0.02
