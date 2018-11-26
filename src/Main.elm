module Main exposing (Model, Msg(..), init, main, update, view)

import Browser
import Browser.Events
import Browser.Navigation as Nav
import Element as E exposing (el, px, text)
import Element.Background as Bg
import Element.Input as Input exposing (button)
import Games.Chansey as Chansey
import Games.Platformer.Model as PlatformerModel
import Games.Platformer.Update as PlatformerUpdate
import Games.Platformer.View as PlatformerView
import Games.Snake.Model as SnakeModel
import Games.Snake.Update as SnakeUpdate
import Games.Snake.View as SnakeView
import Html exposing (Html)
import Key
import Ports
import Time
import Url
import Url.Parser exposing ((</>), Parser, oneOf, s)


type Game
    = Snake
    | Chansey
    | Platformer


type GameState
    = NoGame
    | PlayingSnake SnakeModel.Model
    | PlayingChansey Chansey.Model
    | PlayingPlatformer PlatformerModel.Model


gameStateParser : Parser (GameState -> a) a
gameStateParser =
    oneOf
        [ Url.Parser.map NoGame Url.Parser.top
        , Url.Parser.map (PlayingSnake SnakeModel.init)
            (s <| String.toLower <| gameName Snake)
        , Url.Parser.map (PlayingChansey Chansey.init)
            (s <| String.toLower <| gameName Chansey)
        , Url.Parser.map (PlayingPlatformer PlatformerModel.init)
            (s <| String.toLower <| gameName Platformer)
        ]


gameName : Game -> String
gameName game =
    case game of
        Snake ->
            "Snake"

        Chansey ->
            "Chansey"

        Platformer ->
            "Platformer"


games : List Game
games =
    [ Snake, Chansey, Platformer ]


type alias Model =
    { navKey : Nav.Key, gameState : GameState }


init : Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init url key =
    ( { navKey = key, gameState = url |> stripBasePath |> urlToGameState }
    , Cmd.none
    )


urlToGameState : Url.Url -> GameState
urlToGameState url =
    Url.Parser.parse gameStateParser url |> Maybe.withDefault NoGame


type Msg
    = SnakeMsg SnakeUpdate.Msg
    | ChanseyMsg Chansey.Msg
    | PlatformerMsg PlatformerUpdate.Msg
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url


stripBasePath : Url.Url -> Url.Url
stripBasePath url =
    { url
        | -- This is a hack to work around github-pages and
          -- parser not allowing us to parse the "/"
          -- https://github.com/elm/url/issues/14
          path = String.replace "%PUBLIC_URL%" "" url.path
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlChanged url ->
            ( { model | gameState = url |> stripBasePath |> urlToGameState }
            , Cmd.none
            )

        LinkClicked req ->
            case req of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.navKey (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        SnakeMsg snakeMsg ->
            case model.gameState of
                PlayingSnake snakeModel ->
                    ( { model
                        | gameState =
                            PlayingSnake
                                (SnakeUpdate.update snakeMsg snakeModel)
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        ChanseyMsg chanseyMsg ->
            case model.gameState of
                PlayingChansey chanseyModel ->
                    let
                        ( newChanseyModel, cmd ) =
                            Chansey.update chanseyMsg chanseyModel
                    in
                    ( { model
                        | gameState = PlayingChansey newChanseyModel
                      }
                    , Cmd.map ChanseyMsg cmd
                    )

                _ ->
                    ( model, Cmd.none )

        PlatformerMsg platformerMsg ->
            case model.gameState of
                PlayingPlatformer platformerModel ->
                    ( { model
                        | gameState =
                            PlayingPlatformer
                                (PlatformerUpdate.update platformerMsg platformerModel)
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )


gameUrl : Game -> String
gameUrl game =
    "%PUBLIC_URL%/" ++ (String.toLower <| gameName game)


noGame : Model -> Html Msg
noGame model =
    E.layout
        [ E.centerX
        , E.centerY
        , Bg.color (E.rgb255 20 20 20)
        , E.width E.fill
        , E.height E.fill
        ]
    <|
        E.wrappedRow
            [ E.centerX, E.centerY, E.padding 10, E.spacing 10 ]
            (games
                |> List.map
                    (\game ->
                        el []
                            (E.link
                                [ Bg.color (E.rgb255 85 131 200)
                                , E.padding 10
                                ]
                                { url = gameUrl game
                                , label = text (gameName game)
                                }
                            )
                    )
            )


view : Model -> Browser.Document Msg
view model =
    let
        formatTitle : String -> String
        formatTitle title =
            "Boston Elm Arcade - " ++ title
    in
    case model.gameState of
        NoGame ->
            Browser.Document
                (formatTitle "Choose a Game!")
                [ noGame model ]

        PlayingSnake snakeModel ->
            Browser.Document
                (formatTitle (gameName Snake))
                [ Html.map SnakeMsg (SnakeView.view snakeModel) ]

        PlayingChansey chanseyModel ->
            Browser.Document
                (formatTitle (gameName Chansey))
                [ Html.map ChanseyMsg (Chansey.view chanseyModel) ]

        PlayingPlatformer platformerModel ->
            Browser.Document
                (formatTitle (gameName Platformer))
                [ Html.map PlatformerMsg (PlatformerView.view platformerModel) ]



---- PROGRAM ----


subscriptions : Model -> Sub Msg
subscriptions model =
    -- TODO: Don't make conditional subscriptions until
    -- https://github.com/elm/compiler/issues/1776
    -- is resolved
    Sub.batch
        [ SnakeUpdate.subs SnakeModel.init |> Sub.map SnakeMsg
        , Chansey.subscriptions Chansey.init |> Sub.map ChanseyMsg
        , PlatformerUpdate.subs PlatformerModel.init |> Sub.map PlatformerMsg
        ]


main : Program () Model Msg
main =
    Browser.application
        { view = view
        , init = \_ -> init
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }

-- For local development of a single game
{-
main = Chansey.main
-- -}
