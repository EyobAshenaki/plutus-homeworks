{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}

module Homework2 where

import           Plutus.V2.Ledger.Api (BuiltinData, MintingPolicy,
                                       ScriptContext (scriptContextTxInfo), TokenName, TxOutRef,
                                       mkMintingPolicyScript, TxInfo, scriptContextTxInfo, txInfoInputs, txInInfoOutRef, txInfoMint, unTokenName)
import qualified PlutusTx
import           PlutusTx.Prelude     (Bool (False), ($), (.), traceIfFalse, (==), (&&), any, emptyByteString)
import           Utilities            (wrapPolicy)
import Plutus.V1.Ledger.Value (flattenValue)

{-# INLINABLE mkEmptyNFTPolicy #-}
-- Minting policy for an NFT, where the minting transaction must consume the given UTxO as input
-- and where the TokenName will be the empty ByteString.
mkEmptyNFTPolicy :: TxOutRef -> () -> ScriptContext -> Bool
mkEmptyNFTPolicy _oref () _ctx = traceIfFalse "UTxO not consumed" hasUTxO &&
                                 traceIfFalse "TokenName not empty" hasEmptyTokenName
    where
        info :: TxInfo
        info = scriptContextTxInfo _ctx

        hasUTxO :: Bool
        hasUTxO = any (\i -> txInInfoOutRef i == _oref) $ txInfoInputs info

        hasEmptyTokenName :: Bool
        hasEmptyTokenName = case flattenValue (txInfoMint info) of
            [(_, tn, amt)] -> unTokenName tn == emptyByteString && amt == 1
            _               -> False

{-# INLINABLE mkWrappedEmptyNFTPolicy #-}
mkWrappedEmptyNFTPolicy :: TxOutRef -> BuiltinData -> BuiltinData -> ()
mkWrappedEmptyNFTPolicy = wrapPolicy . mkEmptyNFTPolicy

nftPolicy :: TxOutRef -> TokenName -> MintingPolicy
nftPolicy oref tn = mkMintingPolicyScript $ $$(PlutusTx.compile [|| mkWrappedEmptyNFTPolicy ||]) `PlutusTx.applyCode` PlutusTx.liftCode oref
