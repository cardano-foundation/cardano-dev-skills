# cardano-api reusable outer loop

This complete cardano-api 10.19.1.0 example exposes `balanceWith`, which accepts a candidate builder/provider callback, a fee-dependent `computeOutputs` callback, and a caller-owned bound. `runOuterLoop` supplies the synthetic fixture and reports the distinct `NonConvergent` failure.

## Complete source


```haskell
{-# LANGUAGE OverloadedStrings #-}

module Main (
    OuterLoopError (..),
    Pass (..),
    balanceWith,
    main,
)
where

import Cardano.Api qualified as Api
import Cardano.Api.Genesis qualified as Genesis
import Cardano.Api.Ledger qualified as Ledger
import Cardano.Api.Plutus qualified as Script
import Cardano.Ledger.Alonzo.Scripts qualified as Alonzo
import Cardano.Ledger.Api qualified as LedgerApi
import Cardano.Slotting.EpochInfo qualified as Slotting
import Cardano.Slotting.Slot qualified as Slotting
import Cardano.Slotting.Time qualified as Slotting
import Control.Monad (unless)
import Data.Bifunctor (first)
import Data.Functor.Identity (Identity)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)
import Data.Ratio ((%))
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)
import Lens.Micro ((&))
import System.Environment (lookupEnv)

inputLovelace :: Integer
inputLovelace = 12_000_000

basePayment :: Integer
basePayment = 10_000_000

fixtureAddress :: Api.AddressInEra Api.ConwayEra
fixtureAddress =
    fromMaybe (error "invalid fixture address") $
        Api.deserialiseAddress
            (Api.AsAddressInEra Api.AsConwayEra)
            "addr_test1vzpfxhjyjdlgk5c0xt8xw26avqxs52rtf69993j4tajehpcue4v2v"

fixtureTxIn :: Api.TxIn
fixtureTxIn =
    let txId =
            either (error . show) id $
                Api.deserialiseFromRawBytesHex
                    "be6efd42a3d7b9a00d09d77a5d41e55ceaf0bd093a8aa8a893ce70d9caafd978"
     in Api.TxIn txId (Api.TxIx 0)

fixtureProtocolParams :: Ledger.PParams LedgerApi.ConwayEra
fixtureProtocolParams =
    LedgerApi.upgradePParams conwayUpgrade $
        LedgerApi.upgradePParams () $
            LedgerApi.upgradePParams alonzoUpgrade $
                LedgerApi.upgradePParams () $
                    LedgerApi.upgradePParams () $
                        Genesis.sgProtocolParams Genesis.shelleyGenesisDefaults
  where
    conwayUpgrade :: Ledger.UpgradeConwayPParams Identity
    conwayUpgrade = Ledger.cgUpgradePParams Genesis.conwayGenesisDefaults

    alonzoUpgrade :: LedgerApi.UpgradeAlonzoPParams Identity
    alonzoUpgrade =
        LedgerApi.UpgradeAlonzoPParams
            { LedgerApi.uappCoinsPerUTxOWord = Ledger.CoinPerWord $ Ledger.Coin 34_482
            , LedgerApi.uappCostModels = Alonzo.emptyCostModels
            , LedgerApi.uappPrices =
                Ledger.Prices
                    { Ledger.prSteps = fromMaybe maxBound $ Ledger.boundRational $ 721 % 10_000_000
                    , Ledger.prMem = fromMaybe maxBound $ Ledger.boundRational $ 577 % 10_000
                    }
            , LedgerApi.uappMaxTxExUnits = Ledger.ExUnits 140_000_000 10_000_000_000
            , LedgerApi.uappMaxBlockExUnits = Ledger.ExUnits 62_000_000 20_000_000_000
            , LedgerApi.uappMaxValSize = 5000
            , LedgerApi.uappCollateralPercentage = 150
            , LedgerApi.uappMaxCollateralInputs = 3
            }

coinFromOutput :: Api.TxOut context Api.ConwayEra -> Integer
coinFromOutput (Api.TxOut _ value _ _) =
    case Api.selectLovelace $ Api.txOutValueToValue value of
        Api.Coin lovelace -> lovelace

buildCandidate :: Integer -> Either String (Integer, Integer)
buildCandidate recipient = do
    let sbe = Api.ShelleyBasedEraConway
        content =
            Api.defaultTxBodyContent sbe
                & Api.setTxIns
                    [(fixtureTxIn, Api.BuildTxWith $ Api.KeyWitness Api.KeyWitnessForSpending)]
                & Api.setTxOuts
                    [ Api.TxOut
                        fixtureAddress
                        (Api.lovelaceToTxOutValue sbe $ Api.Coin recipient)
                        Api.TxOutDatumNone
                        Script.ReferenceScriptNone
                    ]
        epochInfo =
            Api.LedgerEpochInfo $
                Slotting.fixedEpochInfo (Slotting.EpochSize 100) (Slotting.mkSlotLength 1000)
        utxo =
            Api.UTxO $
                Map.singleton fixtureTxIn $
                    Api.TxOut
                        fixtureAddress
                        (Api.lovelaceToTxOutValue sbe $ Api.Coin inputLovelace)
                        Api.TxOutDatumNone
                        Script.ReferenceScriptNone
    Api.BalancedTxBody balanced _ change (Ledger.Coin fee) <-
        either (Left . show) Right $
            Api.makeTransactionBodyAutoBalance
                sbe
                (Api.SystemStart $ posixSecondsToUTCTime 0)
                epochInfo
                (Api.LedgerProtocolParameters fixtureProtocolParams)
                mempty
                mempty
                mempty
                utxo
                content
                fixtureAddress
                Nothing
    let outputTotal = sum $ map coinFromOutput $ Api.txOuts balanced
        changeCoin = coinFromOutput change
    unless (inputLovelace == outputTotal + fee) $
        Left "autobalance candidate did not conserve lovelace"
    unless (changeCoin >= 0) $ Left "negative change"
    pure (fee, changeCoin)

data OuterLoopError
    = NonConvergent Int
    | CandidateFailed String
    deriving (Eq, Show)

data Pass = Pass
    { passNumber :: Int
    , guessedFee :: Integer
    , requiredFee :: Integer
    , changeLovelace :: Integer
    }
    deriving (Eq, Show)

balanceWith ::
    (Integer -> Either String (Integer, Integer)) ->
    (Integer -> Either String Integer) ->
    Int ->
    Either OuterLoopError [Pass]
balanceWith builderProvider computeOutputs bound = go [] 1 0
  where
    go observations pass previousFee
        | pass > bound = Left $ NonConvergent bound
        | otherwise = do
            output <- first CandidateFailed $ computeOutputs previousFee
            (fee, change) <- first CandidateFailed $ builderProvider output
            let observation = Pass pass previousFee fee change
            if fee == previousFee
                then Right $ reverse $ observation : observations
                else go (observation : observations) (pass + 1) fee

feeDependentOutput :: Integer -> Either String Integer
feeDependentOutput previousFee =
    let recipient = basePayment - previousFee
     in if recipient >= 0
            then Right recipient
            else Left "fee exceeds base payment"

runOuterLoop :: Int -> IO ()
runOuterLoop bound = do
    passes <-
        either (fail . show) pure $
            balanceWith buildCandidate feeDependentOutput bound
    mapM_ printPass passes
    putStrLn $
        "cardano-api outer loop converged in "
            <> show (length passes)
            <> " passes"
  where
    printPass Pass{passNumber, guessedFee, requiredFee, changeLovelace} =
        putStrLn $
            "pass "
                <> show passNumber
                <> ": guessed fee="
                <> show guessedFee
                <> ", required fee="
                <> show requiredFee
                <> ", change="
                <> show changeLovelace

main :: IO ()
main = do
    falsify <- lookupEnv "FALSIFY"
    runOuterLoop $ maybe 8 (const 1) falsify
```


## Run or check

```sh
nix run --accept-flake-config .#example-cardano-api-outer-loop
```
