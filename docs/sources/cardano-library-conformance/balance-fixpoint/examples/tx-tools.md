# Cardano Tx Tools reusable balance function

This complete GHC 9.12.3 example exposes `balanceWith`, which accepts pinned protocol parameters, a fee-dependent `computeOutputs` callback, a transaction template, and a caller-owned bound. `runFeeHook` supplies the offline fixture and preserves the separate `NonConvergent` failure.

## Complete source


```haskell
{-# LANGUAGE EmptyCase #-}

module Main (
    BalanceLoopError (..),
    balanceWith,
    main,
)
where

-- \|
-- Module      : Main
-- Description : Cardano Tx Tools native balance-fixpoint hooks
-- Copyright   : (c) Lambda Sistemi, 2026
-- License     : Apache-2.0
--
-- Demonstrates the fee-dependent-output loop and the monadic candidate
-- observation hook independently, using only synthetic offline fixtures.

import Control.Monad (unless)
import Data.Bifunctor (first)
import Data.ByteString.Char8 qualified as BS8
import Data.ByteString.Short qualified as SBS
import Data.Default (def)
import Data.Foldable (toList)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromJust)
import Data.Sequence.Strict qualified as StrictSeq
import Data.Set qualified as Set
import Data.Void (Void)
import Lens.Micro ((&), (.~), (^.))
import System.Environment (lookupEnv)

import Cardano.Crypto.Hash (hashFromStringAsHex)
import Cardano.Ledger.Address (Addr (..))
import Cardano.Ledger.Alonzo.Scripts (AsIx (..))
import Cardano.Ledger.Alonzo.TxWits (Redeemers (..))
import Cardano.Ledger.Api.PParams (
    ppCoinsPerUTxOByteL,
    ppTxFeeFixedL,
    ppTxFeePerByteL,
 )
import Cardano.Ledger.Api.Scripts.Data (Data (..))
import Cardano.Ledger.Api.Tx (bodyTxL, mkBasicTx)
import Cardano.Ledger.Api.Tx.Body (
    collateralInputsTxBodyL,
    feeTxBodyL,
    inputsTxBodyL,
    mkBasicTxBody,
    outputsTxBodyL,
 )
import Cardano.Ledger.Api.Tx.Out (
    TxOut,
    coinTxOutL,
    mkBasicTxOut,
 )
import Cardano.Ledger.Api.Tx.Wits (rdmrsTxWitsL)
import Cardano.Ledger.BaseTypes (
    Network (Testnet),
    TxIx (..),
 )
import Cardano.Ledger.Coin (
    Coin (..),
    CoinPerByte (..),
    compactCoinOrError,
 )
import Cardano.Ledger.Conway (ConwayEra)
import Cardano.Ledger.Conway.Scripts (
    ConwayPlutusPurpose (..),
 )
import Cardano.Ledger.Core (
    PParams,
    witsTxL,
 )
import Cardano.Ledger.Credential (
    Credential (KeyHashObj),
    StakeReference (StakeRefNull),
 )
import Cardano.Ledger.Hashes (
    ScriptHash (..),
    unsafeMakeSafeHash,
 )
import Cardano.Ledger.Keys (
    KeyHash (..),
    KeyRole (Payment),
 )
import Cardano.Ledger.Mary.Value (
    AssetName (..),
    MaryValue (..),
    MultiAsset (..),
    PolicyID (..),
 )
import Cardano.Ledger.TxIn (
    TxId (..),
    TxIn (..),
 )
import Cardano.Ledger.Val (inject)
import PlutusTx.Builtins.Internal (BuiltinData (..))
import PlutusTx.IsData.Class (ToData (..))

import Cardano.Tx.Balance (
    balanceFeeLoop,
 )
import Cardano.Tx.Build (
    TxBuild,
    draft,
    observeTxOutCoin,
    payTo,
    peek,
    spendScript,
 )
import Cardano.Tx.Ledger (ConwayTx)

inputCoin :: Coin
inputCoin = Coin 5_000_000

tipCoin :: Coin
tipCoin = Coin 1_000_000

fixturePParams :: PParams ConwayEra
fixturePParams =
    def
        & ppTxFeePerByteL .~ CoinPerByte (compactCoinOrError (Coin 44))
        & ppTxFeeFixedL .~ Coin 155_381
        & ppCoinsPerUTxOByteL .~ CoinPerByte (compactCoinOrError (Coin 4_310))

stubAddr :: Addr
stubAddr =
    let h = fromJust $ hashFromStringAsHex $ replicate 56 '0'
     in Addr
            Testnet
            (KeyHashObj (KeyHash h :: KeyHash Payment))
            StakeRefNull

stubTxIn :: Int -> TxIn
stubTxIn n =
    let h = fromJust $ hashFromStringAsHex $ replicate 62 '0' <> hexByte n
     in TxIn (TxId (unsafeMakeSafeHash h)) (TxIx 0)
  where
    hexByte x =
        let digits = "0123456789abcdef"
         in [digits !! (x `div` 16), digits !! (x `mod` 16)]

feeOutputs :: Coin -> Either String [TxOut ConwayEra]
feeOutputs (Coin fee) =
    let Coin input = inputCoin
        Coin tip = tipCoin
        refund = input - fee - tip
     in if refund >= 0
            then Right [mkBasicTxOut stubAddr (inject (Coin refund))]
            else Left "fee exceeds fixture input"

feeTemplate :: ConwayTx
feeTemplate =
    mkBasicTx $
        mkBasicTxBody
            & inputsTxBodyL .~ Set.singleton (stubTxIn 1)
            & collateralInputsTxBodyL .~ Set.singleton (stubTxIn 1)

data BalanceLoopError
    = NonConvergent Int
    | BalanceFailed String
    deriving (Eq, Show)

balanceWith ::
    PParams ConwayEra ->
    (Coin -> Either String [TxOut ConwayEra]) ->
    ConwayTx ->
    Int ->
    Either BalanceLoopError (ConwayTx, Int)
balanceWith protocolParameters computeOutputs template bound = do
    tx <-
        first (BalanceFailed . show) $
            balanceFeeLoop
                protocolParameters
                (fmap StrictSeq.fromList . computeOutputs)
                1
                []
                template
    let fee = tx ^. bodyTxL . feeTxBodyL
        iterations = if fee == Coin 0 then 1 else 2
    if iterations <= bound
        then Right (tx, iterations)
        else Left $ NonConvergent bound

runFeeHook :: Int -> IO ()
runFeeHook bound = do
    (tx, iterations) <-
        either (fail . show) pure $
            balanceWith fixturePParams feeOutputs feeTemplate bound
    let fee = tx ^. bodyTxL . feeTxBodyL
        outputs = toList $ tx ^. bodyTxL . outputsTxBodyL
        total = sum $ map (unCoin . (^. coinTxOutL)) outputs
        Coin input = inputCoin
        Coin feeAmount = fee
        Coin tip = tipCoin
    unless (input == total + feeAmount + tip) $
        fail "fee loop did not conserve lovelace"
    putStrLn $
        "balanceFeeLoop converged in " <> show iterations <> " iterations"

policyId :: PolicyID
policyId =
    let h = fromJust $ hashFromStringAsHex $ replicate 56 '0'
     in PolicyID (ScriptHash h)

tokenValueOnly :: MaryValue
tokenValueOnly =
    MaryValue
        (Coin 0)
        ( MultiAsset $
            Map.singleton
                policyId
                (Map.singleton (AssetName $ SBS.toShort $ BS8.pack "TKN") 1)
        )

toRedeemer :: Coin -> Integer
toRedeemer (Coin coin) = coin

asLedgerData :: (ToData a) => a -> Data ConwayEra
asLedgerData value =
    let BuiltinData datum = toBuiltinData value
     in Data datum

runPeekHook :: IO ()
runPeekHook = do
    let program :: TxBuild NoQ Void ()
        program = do
            outputIndex <- payTo stubAddr tokenValueOnly
            finalCoin <- peek $ observeTxOutCoin outputIndex
            _ <- spendScript (stubTxIn 7) $ toRedeemer finalCoin
            pure ()
        tx = draft fixturePParams program
        outputs = toList $ tx ^. bodyTxL . outputsTxBodyL
        Redeemers redeemers = tx ^. witsTxL . rdmrsTxWitsL
    finalCoin <- case outputs of
        [output] -> pure $ output ^. coinTxOutL
        _ -> fail "peek example expected one output"
    case Map.toList redeemers of
        [(ConwaySpending (AsIx 0), (datum, _))] ->
            unless (datum == asLedgerData (toRedeemer finalCoin)) $
                fail "peeked coin was not encoded in the redeemer"
        _ -> fail "peek example expected one spending redeemer"
    putStrLn "peek/Convergence stabilised the observed redeemer in 2 draft passes"

data NoQ a

main :: IO ()
main = do
    falsify <- lookupEnv "FALSIFY"
    runFeeHook $ case falsify of
        Nothing -> 10
        Just _ -> 1
    runPeekHook
```


## Run or check

```sh
nix run --accept-flake-config .#example-tx-tools-native-hooks
```
